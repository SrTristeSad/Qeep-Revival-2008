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
from android_navigation import canvas

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

    def test_guest_waits_for_keyboard_and_remeasures_viewport(self):
        img=Image.new('RGB',(1080,1920),(40,40,40))
        draw=ImageDraw.Draw(img)
        draw.rectangle((0,239,1079,350),fill=(125,20,125))
        draw.rectangle((0,1566,1079,1677),fill=(125,20,125))
        ime=img.copy()
        ImageDraw.Draw(ime).rectangle((0,1100,1079,1919),fill=(235,235,235))
        screenshots=iter([img,ime,ime,img,img])
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
        self.assertEqual(taps,[180,175,205])
        self.assertEqual([c.args for c in adb.call_args_list if c.args[:3]==('shell','input','text')],[('shell','input','text','f31guest')])

    def test_guest_never_types_without_keyboard_focus(self):
        img=Image.new('RGB',(1080,1920),(40,40,40))
        draw=ImageDraw.Draw(img)
        draw.rectangle((0,239,1079,350),fill=(125,20,125))
        draw.rectangle((0,1566,1079,1677),fill=(125,20,125))
        with tempfile.TemporaryDirectory() as tmp, \
             patch.object(smoke,'tap'), \
             patch.object(smoke,'screenshot',return_value=img), \
             patch.object(smoke,'adb') as adb:
            with self.assertRaisesRegex(AssertionError,'never opened'):
                smoke.enter_guest_through_android(Path(tmp),canvas(img),Path(tmp)/'trace')
            adb.assert_not_called()

if __name__=='__main__':
    unittest.main()
