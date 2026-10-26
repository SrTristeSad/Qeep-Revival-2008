"""Android UI login with one-time disposable credentials, never saved to disk."""
import re
import secrets
import time
from pathlib import Path
import socket
import struct
from xml.etree import ElementTree

# ASCII-only subset of the local, synthetic protocol. Not a legacy Qeep client.
def _word(text):
    encoded=text.encode('ascii')
    if len(encoded)>65535:
        raise ValueError('field too long')
    return struct.pack('>H',len(encoded))+encoded

def _take(data,pos):
    if pos+2>len(data):
        raise ValueError('truncated reply field')
    count=struct.unpack_from('>H',data,pos)[0]
    end=pos+2+count
    if end>len(data):
        raise ValueError('truncated reply field')
    return data[pos+2:end].decode('ascii'),end

def request(kind,path,props):
    if kind!='P' or path!='/revival/social/register/submit':
        raise ValueError('disposable registration route only')
    body=b'P'+_word(path)+struct.pack('>I',len(props))
    for name,value in sorted(props.items()):
        body+=_word(name)+_word(value)
    body+=struct.pack('>I',0)
    with socket.create_connection(('127.0.0.1',5190),timeout=4) as conn:
        conn.settimeout(4)
        conn.sendall(struct.pack('>I',len(body))+body)
        conn.shutdown(socket.SHUT_WR)
        chunks=[];total=0
        while True:
            chunk=conn.recv(65536)
            if not chunk:break
            total+=len(chunk)
            if total>1048576:
                raise ValueError('reply too large')
            chunks.append(chunk)
    data=b''.join(chunks)
    if not data.startswith(b'R'):
        raise ValueError('invalid response kind')
    response_path,pos=_take(data,1)
    if response_path!=path:
        raise ValueError('unexpected response path')
    if pos+4>len(data):
        raise ValueError('truncated reply')
    count=struct.unpack_from('>I',data,pos)[0];pos+=4
    if count>128:
        raise ValueError('too many response properties')
    received={}
    for _ in range(count):
        key,pos=_take(data,pos)
        value,pos=_take(data,pos)
        received[key]=value
    if pos+4>len(data):
        raise ValueError('invalid payload length')
    length=struct.unpack_from('>I',data,pos)[0];pos+=4
    if pos+length!=len(data):
        raise ValueError('inconsistent payload size')
    return received,data[pos:]

def require(response):
    props,payload=response
    if props.get('ok')!='true':
        raise AssertionError('disposable account registration failed')
    return ElementTree.fromstring(payload.decode('utf8'))



LOGIN='/revival/social/login'
LOGIN_OK='/revival/social/login/submit:ok'

def disposable_credentials():
    username='f35_'+secrets.token_hex(5)
    page=require(request('P','/revival/social/register/submit',
                         {'username':username,'submitId':'register'}))
    form=page.find('form')
    if form is None or form.get('id')!='credentials':
        raise AssertionError('disposable account registration failed')
    codes=[p.get('label','') for p in form.findall('p')
           if re.fullmatch(r'[0-9a-f]{48}',p.get('label',''))]
    if len(codes)!=1:
        raise AssertionError('invalid number of disposable codes')
    return username,codes[0]

def press(code,adb):
    adb('shell','input','keyevent',str(code),timeout=20)
    time.sleep(.35)

def relaunch(output:Path,package:str):
    from android_smoke import adb,DEFAULT_ACTIVITY
    from android_navigation import alive,canvas,screenshot
    adb('shell','am','force-stop',package)
    adb('shell','am','start','-n',f'{package}/{DEFAULT_ACTIVITY}')
    for _ in range(15):
        time.sleep(1)
        if not alive(package):continue
        frame=screenshot(output,'24-login-menu')
        try:geo=canvas(frame)
        except ValueError:continue
        if geo['width_coverage']>=.95:return geo
    raise AssertionError('login menu never rendered after restart')

def login_through_android(output:Path,package:str,trace:Path):
    from android_smoke import adb
    from android_navigation import screenshot,canvas,tap,alive
    from android_server_smoke import observed_routes,MENU_Y,MENU_ROW,keyboard_obscures_canvas
    username,secret=disposable_credentials()
    geo=relaunch(output,package)
    tap(geo,120,MENU_Y+6*MENU_ROW+11)
    screenshot(output,'25-login-welcome')
    # Join is focused; two downs select the following Login link.
    press(20,adb);press(20,adb);press(66,adb)
    if not observed_routes(trace,(LOGIN,))[LOGIN]:
        raise AssertionError('Android did not request the login form')
    form=screenshot(output,'26-empty-login-form')
    if canvas(form)['width_coverage']<.95:
        raise AssertionError('login form never rendered')
    press(66,adb)
    for _ in range(5):
        if keyboard_obscures_canvas(screenshot(output,'27-login-username-ime')):
            break
        time.sleep(.5)
    else:
        raise AssertionError('username editor never opened Android keyboard')
    adb('shell','input','text',username,timeout=25)
    press(66,adb)
    press(20,adb);press(66,adb) # select/edit secret
    # Stop ALL screenshots before entering the bearer.
    try:
        adb('shell','input','text',secret,timeout=25)
    except Exception:
        # A CalledProcessError can contain its command-line args.
        raise AssertionError('secret input failed (details redacted)') from None
    press(66,adb)
    press(20,adb);press(66,adb) # Login button
    time.sleep(1)
    if not observed_routes(trace,(LOGIN_OK,))[LOGIN_OK]:
        raise AssertionError('Android login not approved by Lua server')
    if not alive(package):raise AssertionError('Android process terminated')
    return {'login_server_confirmed':True,'credentials_logged':False,
            'credential_screenshots':False,'interface':'Android UI keys and IME'}
