"""Synthetic assets only; must not be labeled as a screenshot of the historic client."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]

def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class VisualTests(unittest.TestCase):
    def test_identical_and_one_pixel(self):
        visual = load('compare_visual')
        a = Image.new('RGB', (2, 2), (255, 255, 255))
        b = a.copy()
        self.assertTrue(visual.compare(a, b)['pixel_identical'])
        b.putpixel((0, 1), (255, 0, 0))
        result = visual.compare(a, b)
        self.assertEqual(result['pixels_changed'], 1)
        self.assertEqual(result['pixels_checked'], 4)
        self.assertEqual(result['mean_absolute_error_rgb'], 42.5)
        self.assertTrue(visual.compare(a, b, [(0, 1, 1, 1)])['pixel_identical'])

    def test_scale_crop_and_reject_wrong_size(self):
        visual = load('compare_visual')
        a = Image.new('RGBA', (10, 10), 'red')
        scaled = visual.crop_and_normalize(a, (2, 2, 4, 4), 2)
        self.assertEqual(scaled.size, (2, 2))
        with self.assertRaises(ValueError):
            visual.crop_and_normalize(a, (8, 8, 5, 5), 1)
        with self.assertRaises(ValueError):
            visual.compare(scaled, Image.new('RGB', (3, 3)))
        with self.assertRaises(ValueError):
            visual.compare(scaled, scaled, [(0, 0, 2, 2)])

    def test_preflight_manifest_validation_and_no_run(self):
        emu = load('j2me_preflight')
        with tempfile.TemporaryDirectory() as td:
            jar = Path(td) / 'sample.jar'
            with ZipFile(jar, 'w') as z:
                z.writestr('META-INF/MANIFEST.MF',
                           'MIDlet-Name: qeep\nMIDlet-Version: 1.29\n'
                           'MIDlet-Vendor: Blue Lion mobile\n'
                           'MicroEdition-Profile: MIDP-2.0\n'
                           'MicroEdition-Configuration: CLDC-1.0\n')
                z.writestr('joca/Joca.class', 'synthetic-test-only')
            record = emu.inspect_midlet(jar)
            self.assertEqual(record['version'], '1.29')
            self.assertFalse(record['startup_screen_verified'])
            cmd = emu.command_for('freej2me', Path('/tmp/freej2me.jar'), jar)
            self.assertEqual(cmd[:2], ['java', '-jar'])
            self.assertTrue(cmd[-1].startswith('file:///'))
            with ZipFile(jar, 'w') as z:
                z.writestr('META-INF/MANIFEST.MF', 'MIDlet-Name: changed\n')
            with self.assertRaises(ValueError):
                emu.inspect_midlet(jar)


if __name__ == '__main__':
    unittest.main()
