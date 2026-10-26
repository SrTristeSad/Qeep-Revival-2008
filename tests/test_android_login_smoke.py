"""Offline regressions: bearer code never captured and server confirmation required."""
import sys, unittest
from pathlib import Path
from unittest.mock import patch
from xml.etree import ElementTree
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import android_login_smoke as login

class LoginTests(unittest.TestCase):
    def test_disposable_credentials(self):
        document=ElementTree.fromstring('<jcl><form id="credentials"><p label="'+('a'*48)+'"/></form></jcl>')
        with patch.object(login,'request',return_value='response') as request, \
             patch.object(login,'require',return_value=document):
            username,code=login.disposable_credentials()
        self.assertRegex(username,r'^f35_[0-9a-f]{10}$')
        self.assertEqual(code,'a'*48)
        self.assertEqual(request.call_args.args[1],'/revival/social/register/submit')

    def test_ambiguous_code_fails_closed(self):
        document=ElementTree.fromstring('<jcl><form id="credentials"><p label="'+('a'*48)+'"/><p label="'+('b'*48)+'"/></form></jcl>')
        with patch.object(login,'request',return_value='response'), \
             patch.object(login,'require',return_value=document):
            with self.assertRaises(AssertionError):login.disposable_credentials()

    def scenario(self,success):
        import android_navigation,android_server_smoke,android_smoke
        secret='e'*48
        submitted=[False];captures=[]
        def adb(*args,**kwargs):
            if args[:3]==('shell','input','text') and args[3]==secret:
                submitted[0]=True
            return ''
        def shot(output,name):
            self.assertFalse(submitted[0],'secret-bearing screen was captured')
            captures.append(name)
            return 'safe image'
        def routes(path,requests):
            return {name:(name==login.LOGIN or success) for name in requests}
        with patch.object(login,'disposable_credentials',return_value=('f35_dummy',secret)), \
             patch.object(login,'relaunch',return_value={'width_coverage':1.0}), \
             patch.object(android_navigation,'tap'), \
             patch.object(android_navigation,'screenshot',side_effect=shot), \
             patch.object(android_navigation,'canvas',return_value={'width_coverage':1.0}), \
             patch.object(android_navigation,'alive',return_value=True), \
             patch.object(android_server_smoke,'keyboard_obscures_canvas',return_value=True), \
             patch.object(android_server_smoke,'observed_routes',side_effect=routes), \
             patch.object(android_smoke,'adb',side_effect=adb), \
             patch.object(login,'press'),patch.object(login.time,'sleep'):
            if success:
                result=login.login_through_android(Path('/tmp/qa'),'com.test',Path('/tmp/route'))
                self.assertTrue(result['login_server_confirmed'])
            else:
                with self.assertRaisesRegex(AssertionError,'not approved'):
                    login.login_through_android(Path('/tmp/qa'),'com.test',Path('/tmp/route'))
        self.assertTrue(submitted[0])
        self.assertEqual(captures[-1],'27-login-username-ime')

    def test_never_screenshot_after_code(self):self.scenario(True)
    def test_route_must_confirm_success(self):self.scenario(False)

if __name__=='__main__':unittest.main()
