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

def keyboard_obscures_canvas(image):
    """The original two purple UI bands disappear when Android opens its IME.

    This is a geometry-only indicator, not proof that text was submitted.
    """
    try:
        return canvas(image)['width_coverage'] < 0.70
    except ValueError:
        return True


def enter_guest_through_android(output, geometry, route_trace):
    """Wait for actual text focus and remeasure the viewport after IME closes."""
    focus = None
    for i, y in enumerate((180,175,185),1):
        tap(geometry,120,y)
        focus=screenshot(output,f'10-guest-focus-{i}')
        if keyboard_obscures_canvas(focus):
            break
    else:
        raise AssertionError('nickname editor never opened Android keyboard')
    # Sending text before keyboard focus loses characters on Android 34.
    adb('shell','input','text','f31guest')
    time.sleep(1.0)
    screenshot(output,'11-guest-typed')
    adb('shell','input','keyevent','66')  # complete text editing
    closed=None
    for i in range(6):
        time.sleep(.65)
        closed=screenshot(output,f'12-keyboard-closed-{i}')
        if not keyboard_obscures_canvas(closed):
            break
    else:
        adb('shell','input','keyevent','4')  # dismiss Android IME
        time.sleep(1.0)
        closed=screenshot(output,'12-back-dismiss-ime')
        if keyboard_obscures_canvas(closed):
            raise AssertionError('Android editor did not dismiss after submit')
    actual=canvas(closed)
    if actual['width_coverage']<.95:
        raise AssertionError('Android viewport not restored after IME')
    tap(actual,120,205)
    home=screenshot(output,'13-guest-submit')
    routes=observed_routes(route_trace,('/revival/social/join',))
    if not routes['/revival/social/join']:
        tap(actual,120,208)  # retry only if server did not receive it
        home=screenshot(output,'14-guest-retry')
        routes=observed_routes(route_trace,('/revival/social/join',))
    if not routes['/revival/social/join']:
        raise AssertionError('Android guest join never reached the Lua server')
    return {'ime_opened':True,'ime_closed':True,
            'screen_difference':round(pixels_changed(closed,home,actual),5)}


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
        # Android IME changes window geometry: never reuse the old tap
        # coordinates while its on-screen keyboard is open.
        guest_result=enter_guest_through_android(output,geom,trace)
        record['routes_observed']['/revival/social/join']=True
        passed('android_guest_join_reached_server',**guest_result)
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
    parser.add_argument('--verify-social-tcp',action='store_true',
                        help='host TCP smoke for local disposable accounts and guest messages')
    a=parser.parse_args()
    if a.start_local_server:
        if a.server_pid is not None:
            parser.error('--server-pid and --start-local-server cannot be combined')
        with managed_server(a.route_trace,a.server_log) as child:
            ok=run(a.output,a.package,child.pid,a.route_trace)
            if ok and a.verify_social_tcp:
                # These are real loopback TCP checks against the same server.
                # They do not claim credentials were entered on Android.
                results={}
                for script in ('tests/test_socket_accounts.lua','tests/test_socket_social.lua'):
                    completed=subprocess.run(['lua5.4',script],cwd=Path(__file__).resolve().parents[1],
                                             capture_output=True,text=True,timeout=30)
                    results[script]={'passed':completed.returncode==0}
                    if completed.returncode:
                        ok=False
                (a.output/'host-social-tcp.json').write_text(
                    json.dumps({'passed':ok,'kind':'host_TCP_not_Android_UI',
                                'checks':results},indent=2)+'\n',encoding='utf-8')
    else:
        if a.verify_social_tcp:
            parser.error('--verify-social-tcp requires --start-local-server')
        ok=run(a.output,a.package,a.server_pid,a.route_trace)
    print('Android -> Lua server:', 'PASS' if ok else 'FAIL', a.output)
    return 0 if ok else 1

if __name__=='__main__':
    raise SystemExit(main())
