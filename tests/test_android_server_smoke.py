"""Offline tests for the loopback-only Android network smoke."""
import sys
import tempfile
import unittest
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

if __name__=='__main__':
    unittest.main()
