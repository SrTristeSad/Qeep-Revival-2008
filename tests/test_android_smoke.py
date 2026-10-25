"""Unit tests for Android emulator startup classification."""
import importlib.util
from pathlib import Path
import unittest
path=Path(__file__).resolve().parents[1]/'tools'/'android_smoke.py'
spec=importlib.util.spec_from_file_location('android_smoke',path)
smoke=importlib.util.module_from_spec(spec)
spec.loader.exec_module(smoke)
PKG=smoke.DEFAULT_PACKAGE
START=f'Starting: Intent {{ cmp={PKG}/{smoke.DEFAULT_ACTIVITY} }}\nStatus: ok'
IMG=smoke.PNG_HEADER+b'\0'*200

class AndroidSmokeTests(unittest.TestCase):
    def test_running(self):
        ok,err=smoke.result_ok(START,['1022','1022'],IMG,'',PKG)
        self.assertTrue(ok,err)
    def test_early_exit(self):
        self.assertFalse(smoke.result_ok(START,['1022',''],IMG,'',PKG)[0])
    def test_fatal(self):
        ok,err=smoke.result_ok(START,['1022','1022'],IMG,'FATAL EXCEPTION: main',PKG)
        self.assertFalse(ok)
        self.assertIn('Android crash signature in logcat',err)
    def test_capture(self):
        self.assertFalse(smoke.result_ok(START,['1022','1022'],b'','',PKG)[0])
    def test_wrong_app(self):
        self.assertFalse(smoke.result_ok(START,['1022','1022'],IMG,'','com.other')[0])
    def test_bad_activity(self):
        self.assertFalse(smoke.result_ok(START+'\nError: Activity class does not exist',['1022','1022'],IMG,'',PKG)[0])

if __name__=='__main__': unittest.main()
