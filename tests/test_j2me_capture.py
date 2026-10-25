"""Tests never execute an unknown/real MIDlet or reach the network."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from zipfile import ZipFile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / 'tools' / 'j2me_capture.py'
spec = importlib.util.spec_from_file_location('j2me_capture', MODULE)
import sys
sys.path.insert(0, str(MODULE.parent))
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.TemporaryDirectory()
        self.addCleanup(self.td.cleanup)
        self.p = Path(self.td.name)
        self.midlet = self.p / 'qeep.jar'
        self.emulator = self.p / 'microemulator.jar'
        with ZipFile(self.midlet, 'w') as z:
            z.writestr('META-INF/MANIFEST.MF',
                       'MIDlet-Name: qeep\nMIDlet-Version: 1.29\nMIDlet-Vendor: Blue Lion mobile\n'
                       'MicroEdition-Profile: MIDP-2.0\nMicroEdition-Configuration: CLDC-1.0\n')
            z.writestr('joca/Joca.class', 'synthetic')
        with ZipFile(self.emulator, 'w') as z:
            z.writestr('META-INF/MANIFEST.MF', 'Main-Class: org.microemu.app.Main\n')
            z.writestr('org/microemu/app/Main.class', 'synthetic')

    def test_expected_original_hash_enforced(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            capture.validate_inputs(self.midlet, self.emulator, 'microemulator')
        verified = capture.validate_inputs(self.midlet, self.emulator, 'microemulator',
                                           allow_other_jar=True)
        self.assertTrue(verified['emulator_sha256'])
        self.assertEqual(verified['version'], '1.29')

    def test_invalid_emulator_rejected(self):
        other = self.p / 'not-a-jar.jar'
        other.write_text('broken')
        with self.assertRaises(ValueError):
            capture.validate_inputs(self.midlet, other, 'microemulator', True)
        with ZipFile(other, 'w') as z:
            z.writestr('META-INF/MANIFEST.MF', 'Fake: 1')
        with self.assertRaisesRegex(ValueError, 'MicroEmulator'):
            capture.validate_inputs(self.midlet, other, 'microemulator', True)

    def test_capture_report_never_claims_historical_page(self):
        png = self.p / 'synthetic-test.png'
        Image.new('RGB', (4, 4), 'purple').save(png)
        result = capture.create_report({'version': '1.29'}, png, live=True,
                                       exit_code=None, duration=2, command=['unshare', '-n'])
        self.assertEqual(result['capture_sha256'], capture.sha256_file(png))
        self.assertTrue(result['manual_visual_review_required'])
        self.assertFalse(result['specific_historic_screen_verified'])
        self.assertNotIn('Qeep visualmente confirmado', json.dumps(result))

    def test_namespace_failure_is_fail_closed(self):
        with patch.object(capture.platform, 'system', return_value='Linux'):
            with patch.object(capture.shutil, 'which', return_value='/usr/bin/fake'):
                with patch.object(capture.subprocess, 'run') as run:
                    run.return_value.returncode = 1
                    with self.assertRaisesRegex(RuntimeError, 'NÃO foi executado'):
                        capture.check_isolation()
                    run.assert_called_once()

    def test_dry_run_never_starts_processes(self):
        with patch.object(capture, 'validate_inputs', return_value={'sha256': capture.EXPECTED_SHA}):
            with patch.object(capture, 'run_capture') as run:
                self.assertEqual(capture.main([str(self.midlet), '--emulator', str(self.emulator)]), 0)
                run.assert_not_called()


if __name__ == '__main__':
    unittest.main()