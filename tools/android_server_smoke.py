#!/usr/bin/env python3
"""Android-to-Lua-server integration: real UI taps and loopback-only TCP.
Logs only route names; screenshots alone do not prove a request was received.
"""
import argparse
from contextlib import contextmanager
import subprocess
import json
import os
from pathlib import Path
import socket
import time
from android_smoke import DEFAULT_PACKAGE, adb
from android_navigation import canvas, pixels_changed, screenshot, tap, alive

PORT=5190
MENU_Y,MENU_ROW=91,22

def tcp_ready(port=PORT, tries=30):
    for _ in range(tries):
        try:
            with socket.create_connection(('127.0.0.1',port),timeout=.4):
                return True
        except OSError:
            time.sleep(.4)
    return False

def observed_routes(file, expected):
    observed=set(file.read_text(encoding='utf-8').splitlines()) if file.exists() else set()
    return {item:item in observed for item in expected}

def type_endpoint(value):
    if value!='127.0.0.1:5190':
        raise ValueError('only loopback test target permitted')
    adb('shell','input','text',value)
    time.sleep(.8)

def changed(a,b,geom,threshold=.035):
    value=pixels_changed(a,b,geom)
    if value<threshold:
        raise AssertionError('screen did not change as expected: %.5f'%value)
    return round(value,5)

@contextmanager
def managed_server(trace, log_path, executable='lua5.4'):
    """Launch only a loopback server and keep it alive within this Python process.

    The emulator action runs each script line in its own shell, so shell $!
    variables do not persist. Cleanup runs even after failed adb assertions.
    """
    trace=Path(trace).resolve()
    log_path=Path(log_path).resolve()
    trace.parent.mkdir(parents=True,exist_ok=True)
    log_path.parent.mkdir(parents=True,exist_ok=True)
    trace.unlink(missing_ok=True)  # reject stale route evidence
    env=os.environ.copy()
    env['QEEP_ROUTE_TRACE']=str(trace)
    with log_path.open('wb') as logfile:
        child=subprocess.Popen(
            [executable,'server/main.lua','127.0.0.1',str(PORT)],
            stdin=subprocess.DEVNULL,stdout=logfile,stderr=subprocess.STDOUT,
            env=env,cwd=Path(__file__).resolve().parents[1])
        try:
            yield child
        finally:
            if child.poll() is None:
                child.terminate()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)

def run(output,package,server_pid,trace):
    output.mkdir(parents=True,exist_ok=True)
    record={'package':package,'passed':False,'checks':[],'transport':'adb reverse tcp:5190'}
    checks=record['checks']
    def passed(name, **details):
        checks.append({'name':name,'passed':True,**details})
    try:
        if not tcp_ready(): raise RuntimeError('Lua server not listening on loopback')
        if server_pid and not os.path.exists('/proc/'+str(server_pid)):
            raise RuntimeError('Lua server terminated before test')
        if not alive(package):raise RuntimeError('Android client not running')
        adb('reverse','tcp:5190','tcp:5190')
        if 'tcp:5190 tcp:5190' not in adb('reverse','--list'):
            raise AssertionError('adb reverse missing')
        passed('local_tcp_forward')
        # Prior touch test ends at JCL index after returning from fields.
        offline=screenshot(output,'01-before')
        geom=canvas(offline)
        tap(geom,45,307)
        menu=screenshot(output,'02-menu')
        passed('return_to_menu',difference=changed(offline,menu,geom))
        tap(geom,120,MENU_Y+3*MENU_ROW+11)
        editor=screenshot(output,'03-config')
        passed('open_endpoint_config',difference=changed(menu,editor,geom))
        type_endpoint('127.0.0.1:5190')
        screenshot(output,'04-typed')
        adb('shell','input','keyevent','66')
        time.sleep(1)
        after_enter=screenshot(output,'05-after-enter')
        if pixels_changed(menu,after_enter,geom)>.095:
            tap(geom,45,307)
        configured=screenshot(output,'06-config-saved')
        passed('configured_endpoint',difference=changed(editor,configured,geom,.03))
        tap(geom,120,MENU_Y+2*MENU_ROW+11)
        ping=screenshot(output,'07-ping-response')
        passed('ping_result_screen',difference=changed(configured,ping,geom))
        tap(geom,120,307)
        back=screenshot(output,'08-menu')
        passed('dismiss_result',difference=changed(ping,back,geom))
        tap(geom,120,MENU_Y+6*MENU_ROW+11)
        social=screenshot(output,'09-social')
        passed('social_start_screen',difference=changed(back,social,geom))
        received=observed_routes(trace,('/revival/ping','/revival/social/start'))
        record['routes_observed']=received
        for route,ok in received.items():
            if not ok:raise AssertionError('Lua server never received '+route)
            passed('server_received_'+route.replace('/','_'))
        if not alive(package):raise AssertionError('APK process died')
        passed('client_alive')
        record['passed']=True
    except Exception as error:
        record['errors']=[type(error).__name__+': '+str(error)]
    finally:
        try:
            (output/'logcat.txt').write_text(adb('logcat','-d','-v','brief',timeout=45),encoding='utf-8')
        except Exception as error:
            record['logcat_error']=str(error)[:250]
        (output/'result.json').write_text(json.dumps(record,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    return record['passed']

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=Path('android-server-results'))
    parser.add_argument('--package',default=DEFAULT_PACKAGE)
    parser.add_argument('--server-pid',type=int,help='externally managed server PID')
    parser.add_argument('--start-local-server',action='store_true',help='manage loopback Lua process')
    parser.add_argument('--server-log',type=Path,default=Path('android-server.log'))
    parser.add_argument('--route-trace',type=Path,default=Path('android-server-routes.log'))
    a=parser.parse_args()
    if a.start_local_server:
        if a.server_pid is not None:
            parser.error('--server-pid and --start-local-server cannot be combined')
        with managed_server(a.route_trace,a.server_log) as child:
            ok=run(a.output,a.package,child.pid,a.route_trace)
    else:
        ok=run(a.output,a.package,a.server_pid,a.route_trace)
    print('Android -> Lua server:', 'PASS' if ok else 'FAIL', a.output)
    return 0 if ok else 1

if __name__=='__main__':
    raise SystemExit(main())
