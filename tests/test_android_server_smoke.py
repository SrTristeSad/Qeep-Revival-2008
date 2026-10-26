"""Offline tests for the loopback-only Android network smoke."""
import sys
import tempfile
import unittest
import subprocess
from unittest.mock import MagicMock
from pathlib import Path
from unittest.mock import patch
from PIL import Image, ImageDraw
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import android_server_smoke as smoke
m = smoke  # alias for Phase 33 registration regression tests
from android_navigation import canvas, logical_point

class AndroidServerSmokeTests(unittest.TestCase):
    def test_only_loopback_endpoint(self):
        with self.assertRaises(ValueError):
            smoke.type_endpoint('192.168.1.10:5190')
        with self.assertRaises(ValueError):
            smoke.type_endpoint('qeep.com:5190')
        with patch.object(smoke,'adb') as adb,patch.object(smoke.time,'sleep'):
            smoke.type_endpoint('127.0.0.1:5190')
            adb.assert_called_once_with('shell','input','text','127.0.0.1:5190')
    def test_ready_uses_loopback(self):
        with patch.object(smoke.socket,'create_connection',side_effect=OSError) as mock,patch.object(smoke.time,'sleep'):
            self.assertFalse(smoke.tcp_ready(5190,tries=2))
            self.assertEqual(mock.call_args_list[0].args[0],('127.0.0.1',5190))
        with patch.object(smoke.socket,'create_connection') as mock:
            self.assertTrue(smoke.tcp_ready(5190,tries=1))
            mock.assert_called_once_with(('127.0.0.1',5190),timeout=.4)
    def test_route_log_requires_both_exact_paths(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'routes'
            routes=('/revival/ping','/revival/social/start')
            self.assertEqual(smoke.observed_routes(path,routes),dict.fromkeys(routes,False))
            path.write_text('/revival/ping-extra\n/revival/social/start\n')
            self.assertEqual(smoke.observed_routes(path,routes),{'/revival/ping':False,'/revival/social/start':True})
            path.write_text('/revival/ping\n/revival/social/start\n')
            self.assertTrue(all(smoke.observed_routes(path,routes).values()))
    def test_manager_holds_server_within_python_and_discards_stale_trace(self):
        with tempfile.TemporaryDirectory() as tmp:
            trace=Path(tmp)/'trace.log'
            logfile=Path(tmp)/'server.log'
            trace.write_text('/revival/ping\n')
            child=MagicMock()
            child.pid=4567
            child.poll.return_value=None
            with patch.object(smoke.subprocess,'Popen',return_value=child) as popen:
                with smoke.managed_server(trace,logfile) as running:
                    self.assertIs(running,child)
                    self.assertFalse(trace.exists())
                    args,kwargs=popen.call_args
                    self.assertEqual(args[0],['lua5.4','server/main.lua','127.0.0.1','5190'])
                    self.assertEqual(kwargs['env']['QEEP_ROUTE_TRACE'],str(trace.resolve()))
                    self.assertEqual(kwargs['stdin'],subprocess.DEVNULL)
                child.terminate.assert_called_once()
                child.wait.assert_called_once_with(timeout=5)

    def test_manager_reaps_child_after_failure_and_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            child=MagicMock()
            child.poll.return_value=None
            child.wait.side_effect=[subprocess.TimeoutExpired('lua5.4',5),0]
            with patch.object(smoke.subprocess,'Popen',return_value=child):
                with self.assertRaisesRegex(RuntimeError,'test failure'):
                    with smoke.managed_server(Path(tmp)/'trace',Path(tmp)/'log'):
                        raise RuntimeError('test failure')
            child.terminate.assert_called_once()
            child.kill.assert_called_once()
            self.assertEqual(child.wait.call_count,2)

    def test_change_checks_pixels_not_text(self):
        img=Image.new('RGB',(1080,1920),(40,40,40))
        draw=ImageDraw.Draw(img)
        draw.rectangle((0,239,1079,350),fill=(125,20,125))
        draw.rectangle((0,1566,1079,1677),fill=(125,20,125))
        geom=canvas(img)
        with self.assertRaises(AssertionError):
            smoke.changed(img,img,geom)
        other=img.copy()
        ImageDraw.Draw(other).rectangle((200,700,800,1050),fill=(255,255,255))
        self.assertGreater(smoke.changed(img,other,geom),.035)

    def test_ime_detector_requires_complete_canvas(self):
        img=Image.new('RGB',(1080,1920),(40,40,40))
        draw=ImageDraw.Draw(img)
        draw.rectangle((0,239,1079,350),fill=(125,20,125))
        draw.rectangle((0,1566,1079,1677),fill=(125,20,125))
        self.assertFalse(smoke.keyboard_obscures_canvas(img))
        draw.rectangle((0,1100,1079,1919),fill=(235,235,235))
        self.assertTrue(smoke.keyboard_obscures_canvas(img))

    @staticmethod
    def guest_screen():
        img=Image.new('RGB',(1080,1920),(40,40,40))
        d=ImageDraw.Draw(img)
        d.rectangle((0,239,1079,350),fill=(125,20,125))
        d.rectangle((0,1566,1079,1677),fill=(125,20,125))
        geo=canvas(img)
        d.rectangle((*logical_point(geo,15,208),*logical_point(geo,225,226)),outline=(160,180,25),width=5)
        d.rectangle((*logical_point(geo,11,234),*logical_point(geo,229,259)),fill=(205,255,60))
        return img

    def test_detect_actual_guest_input_and_submit(self):
        img=self.guest_screen()
        self.assertEqual(smoke.guest_controls(img,canvas(img)),{'input_y':217,'submit_y':246})
        geo=canvas(img)
        bad=img.copy()
        ImageDraw.Draw(bad).rectangle((*logical_point(geo,11,234),*logical_point(geo,229,259)),fill=(235,255,185))
        with self.assertRaisesRegex(AssertionError,'not highlighted'):
            smoke.guest_controls(bad,geo)
        self.assertEqual(smoke.guest_controls(bad,geo,require_button=False)['input_y'],217)

    def test_guest_waits_for_keyboard_and_remeasures_viewport(self):
        img=self.guest_screen()
        ime=img.copy()
        ImageDraw.Draw(ime).rectangle((0,1100,1079,1919),fill=(235,235,235))
        screenshots=iter([img,ime,ime,img,img,img])
        taps=[]
        def tap(geom,x,y):
            taps.append(y)
        def routes(file,expected):
            return {name:(name=='/revival/social/join') for name in expected}
        with tempfile.TemporaryDirectory() as tmp, \
             patch.object(smoke,'screenshot',side_effect=lambda *args:next(screenshots)), \
             patch.object(smoke,'tap',side_effect=tap), \
             patch.object(smoke,'adb') as adb, \
             patch.object(smoke,'observed_routes',side_effect=routes), \
             patch.object(smoke.time,'sleep'):
            data=smoke.enter_guest_through_android(Path(tmp),canvas(img),Path(tmp)/'trace')
        self.assertTrue(data['ime_opened'] and data['ime_closed'])
        self.assertEqual(taps,[217,246])
        self.assertEqual([c.args for c in adb.call_args_list if c.args[:3]==('shell','input','text')],[('shell','input','text','f32guest')])

    def test_guest_never_types_without_keyboard_focus(self):
        img=self.guest_screen()
        with tempfile.TemporaryDirectory() as tmp, \
             patch.object(smoke,'tap'), \
             patch.object(smoke,'screenshot',return_value=img), \
             patch.object(smoke,'adb') as adb:
            with self.assertRaisesRegex(AssertionError,'never opened'):
                smoke.enter_guest_through_android(Path(tmp),canvas(img),Path(tmp)/'trace')
            adb.assert_not_called()

if __name__=='__main__':
    unittest.main()


class AndroidRegistrationRegression(unittest.TestCase):
    def test_registration_success_only(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'routes.log'
            self.assertFalse(m.registration_approved(path))
            path.write_text('/revival/social/register/submit:error\n',encoding='utf8')
            self.assertFalse(m.registration_approved(path))
            path.write_text('/revival/social/register/submit:ok\n',encoding='utf8')
            self.assertTrue(m.registration_approved(path))

    def test_never_capture_bearer_screen(self):
        with patch.object(m,'adb') as adb, \
             patch.object(m.time,'sleep'), \
             patch.object(m,'alive',return_value=True), \
             patch.object(m,'screenshot') as screenshot, \
             patch.object(m,'canvas',return_value={'width_coverage':1.0}), \
             patch.object(m,'tap'), patch.object(m,'changed'), \
             patch.object(m,'guest_controls',return_value={'input_y':215,'submit_y':246}), \
             patch.object(m,'keyboard_obscures_canvas',side_effect=[True,False]), \
             patch.object(m,'registration_approved',return_value=True), \
             patch.object(m,'observed_routes',return_value={'/revival/social/register':True}):
            result=m.register_android(Path('/tmp/no-creds'),'com.test',Path('/tmp/trace'))
            self.assertTrue(result['approved'])
            self.assertFalse(result['secret_response_screenshot'])
            self.assertEqual(adb.call_args_list[0].args[:3],('shell','am','force-stop'))
            images=[call.args[1] for call in screenshot.call_args_list]
            self.assertFalse(any('credentials' in n or 'success' in n or 'submitted' in n for n in images))


class AndroidRegistrationNavigationTests(unittest.TestCase):
    def test_restart_waits_for_real_render_and_skips_black_frame(self):
        with patch.object(smoke,'adb') as adb, \
             patch.object(smoke.time,'sleep'), \
             patch.object(smoke,'alive',return_value=True), \
             patch.object(smoke,'screenshot',side_effect=['black','real']) as shot, \
             patch.object(smoke,'canvas',side_effect=[ValueError('expected 2 purple bands'),{'width_coverage':.999}]):
            frame, geo=smoke.wait_for_rendered_menu(Path('/tmp/f34'), 'com.example', attempts=3)
            self.assertEqual(frame,'real')
            self.assertGreater(geo['width_coverage'],.95)
            self.assertEqual(shot.call_count,2)
            self.assertEqual(adb.call_args_list[0].args[:3],('shell','am','force-stop'))

    def test_restart_fails_closed_if_only_black_frames(self):
        with patch.object(smoke,'adb'), \
             patch.object(smoke.time,'sleep'), \
             patch.object(smoke,'alive',return_value=True), \
             patch.object(smoke,'screenshot',return_value='black'), \
             patch.object(smoke,'canvas',side_effect=ValueError('black')):
            with self.assertRaisesRegex(AssertionError,'finish rendering'):
                smoke.wait_for_rendered_menu(Path('/tmp/f34'), 'com.example', attempts=2)

    def test_registration_link_touches_only_content_not_footer(self):
        route='/revival/social/register'
        with patch.object(smoke,'tap') as tap, \
             patch.object(smoke.time,'sleep'), \
             patch.object(smoke,'observed_routes',side_effect=[
                 {route:False},{route:True}
             ]):
            selected=smoke.open_registration_link({'width_coverage':1.0},Path('/tmp/fake'))
            self.assertEqual(selected,277)
            self.assertEqual([call.args[2] for call in tap.call_args_list],[274,277])
            self.assertTrue(all(65<call.args[2]<281 for call in tap.call_args_list))

    def test_registration_link_requires_real_server_route(self):
        route='/revival/social/register'
        with patch.object(smoke,'tap') as tap, \
             patch.object(smoke.time,'sleep'), \
             patch.object(smoke,'observed_routes',return_value={route:False}):
            with self.assertRaisesRegex(AssertionError,'did not request'):
                smoke.open_registration_link({'width_coverage':1.0},Path('/tmp/fake'))
            self.assertEqual(tap.call_count,3)
