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
from android_smoke import DEFAULT_PACKAGE, DEFAULT_ACTIVITY, adb
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


# Framebuffer-grounded synthetic form controls, validated against the
# Fase 31 screenshot (logical x=15/225, y=208..226). No OCR or arbitrary taps.
OLIVE_BORDER=(160,180,25)
SELECTED_BUTTON=(205,255,60)


def guest_controls(image, geo, require_button=True):
    from android_navigation import logical_point
    rgb=image.convert('RGB')
    def pixel(x,y):
        px,py=logical_point(geo,x,y)
        if not (0<=px<rgb.width and 0<=py<rgb.height):
            raise AssertionError('guest controls outside framebuffer')
        return rgb.getpixel((px,py))
    def near(a,b):
        return all(abs(x-y)<=5 for x,y in zip(a,b))
    rows=[y for y in range(120,272)
          if near(pixel(15,y),OLIVE_BORDER)
          and near(pixel(225,y),OLIVE_BORDER)]
    groups=[]
    for y in rows:
        if not groups or y>groups[-1][-1]+1:
            groups.append([y])
        else:
            groups[-1].append(y)
    boxes=[g for g in groups if 13<=len(g)<=45]
    if len(boxes)!=1:
        raise AssertionError('expected exactly one guest input outline')
    box=boxes[0]
    submit=box[-1]+20
    if submit>=275:
        raise AssertionError('guest submit row out of bounds')
    if require_button and not near(pixel(15,submit),SELECTED_BUTTON):
        raise AssertionError('guest submit button not highlighted')
    return {'input_y':round((box[0]+box[-1])/2),'submit_y':submit}


def enter_guest_through_android(output, geometry, route_trace):
    """Wait for actual text focus and remeasure the viewport after IME closes."""
    before=screenshot(output,'10-guest-before-focus')
    control=guest_controls(before,canvas(before))
    focus = None
    for i, y in enumerate((control['input_y'],)*3,1):
        tap(geometry,120,y)
        focus=screenshot(output,f'10-guest-focus-{i}')
        if keyboard_obscures_canvas(focus):
            break
    else:
        raise AssertionError('nickname editor never opened Android keyboard')
    # Sending text before keyboard focus loses characters on Android 34.
    adb('shell','input','text','f32guest')
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
    submit=guest_controls(closed,actual,require_button=False)
    tap(actual,120,submit['submit_y'])
    home=screenshot(output,'13-guest-submit')
    routes=observed_routes(route_trace,('/revival/social/join',))
    if not routes['/revival/social/join']:
        tap(actual,120,submit['submit_y'])  # retry only if server did not receive it
        home=screenshot(output,'14-guest-retry')
        routes=observed_routes(route_trace,('/revival/social/join',))
    if not routes['/revival/social/join']:
        raise AssertionError('Android guest join never reached the Lua server')
    return {'ime_opened':True,'ime_closed':True,
            'screen_difference':round(pixels_changed(closed,home,actual),5)}



def registration_approved(trace):
    return observed_routes(trace,('/revival/social/register/submit:ok',))[
        '/revival/social/register/submit:ok']


def wait_for_rendered_menu(output, package, attempts=15):
    """Wait for LOVE canvas after force-stop, not the black Android startup frame.

    A fixed 2-second sleep is insufficient on CI's cold emulator.
    Only pre-authentication frames are captured; bearer-code views are excluded.
    """
    adb('shell','am','force-stop',package)
    adb('shell','am','start','-n',f'{package}/{DEFAULT_ACTIVITY}')
    for attempt in range(attempts):
        time.sleep(1.0)
        if not alive(package):
            continue
        frame=screenshot(output,'16-menu-for-registration')
        try:
            geo=canvas(frame)
        except ValueError:
            continue
        if geo['width_coverage']>=.95:
            return frame,geo
    raise AssertionError('Android menu did not finish rendering after restart')


def open_registration_link(geo, trace):
    """Only tap within JCL content; y >= 281 is footer, not a link."""
    route='/revival/social/register'
    for y in (274,277,270):
        if y>=281:
            raise AssertionError('registration link touch outside JCL content')
        tap(geo,120,y)
        time.sleep(.6)
        if observed_routes(trace,(route,))[route]:
            return y
    raise AssertionError('registration link did not request the form')


def register_android(output, package, trace):
    """Submit test account by touch. Never capture its secret success screen."""
    menu,geo=wait_for_rendered_menu(output,package)
    tap(geo,120,MENU_Y+6*MENU_ROW+11)
    welcome=screenshot(output,'17-welcome-for-registration')
    changed(menu,welcome,geo)
    open_registration_link(canvas(welcome),trace)
    form=screenshot(output,'18-registration-form')
    changed(welcome,form,geo)
    ctl=guest_controls(form,canvas(form),require_button=False)
    tap(canvas(form),120,ctl['input_y'])
    for n in range(5):
        time.sleep(.5)
        if keyboard_obscures_canvas(screenshot(output,'19-registration-ime')):
            break
    else:
        raise AssertionError('registration input did not receive keyboard focus')
    adb('shell','input','text','f33androidlab')
    time.sleep(.5)
    screenshot(output,'20-registration-username')  # no code exists yet
    adb('shell','input','keyevent','66')
    for n in range(6):
        time.sleep(.6)
        closed=screenshot(output,f'21-registration-keyboard-closed-{n}')
        if not keyboard_obscures_canvas(closed):
            break
    else:
        raise AssertionError('registration IME could not close')
    geometry=canvas(closed)
    if geometry['width_coverage']<.95:
        raise AssertionError('Android viewport still obstructed')
    submit=guest_controls(closed,geometry,require_button=False)
    # IMPORTANT: successful response shows a bearer code. NO SCREENSHOT after.
    tap(geometry,120,submit['submit_y'])
    time.sleep(1.0)
    if not registration_approved(trace):
        raise AssertionError('Lua server did not approve registration')
    return {'approved':True,'secret_response_screenshot':False}

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

def run(output,package,server_pid,trace,verify_android_login=False):
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
        registration=register_android(output,package,trace)
        passed('android_account_registration',**registration)
        if verify_android_login:
            from android_login_smoke import login_through_android
            result=login_through_android(output,package,trace)
            passed('android_login_via_UI',**result)
        if not alive(package):raise AssertionError('APK process died')
        passed('client_alive')
        record['passed']=True
    except Exception as error:
        record['errors']=[type(error).__name__+': '+str(error)]
    finally:
        try:
            logcat=adb('logcat','-d','-v','brief',timeout=45)
            if verify_android_login:
                import re
                logcat=re.sub(r'(?<![0-9a-f])[0-9a-f]{48}(?![0-9a-f])',
                              '[REDACTED BEARER CODE]',logcat)
            (output/'logcat.txt').write_text(logcat,encoding='utf-8')
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
    parser.add_argument('--verify-android-login',action='store_true',
                        help='test Android login with a one-use code kept in memory')
    parser.add_argument('--verify-social-tcp',action='store_true',
                        help='host TCP smoke for local disposable accounts and guest messages')
    a=parser.parse_args()
    if a.start_local_server:
        if a.server_pid is not None:
            parser.error('--server-pid and --start-local-server cannot be combined')
        with managed_server(a.route_trace,a.server_log) as child:
            ok=run(a.output,a.package,child.pid,a.route_trace,
                   verify_android_login=a.verify_android_login)
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
        ok=run(a.output,a.package,a.server_pid,a.route_trace,
               verify_android_login=a.verify_android_login)
    print('Android -> Lua server:', 'PASS' if ok else 'FAIL', a.output)
    return 0 if ok else 1

if __name__=='__main__':
    raise SystemExit(main())
