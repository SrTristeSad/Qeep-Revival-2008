"""Synthetic images only: tests never claim a real historic Qeep capture."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
spec = importlib.util.spec_from_file_location('visual_evidence', ROOT / 'tools/visual_evidence.py')
visual = importlib.util.module_from_spec(spec)
spec.loader.exec_module(visual)


class VisualEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.image = self.root / 'simulated-emulator.png'
        im = Image.new('RGB', (70, 80), '#333333')
        for x in range(10, 30):
            for y in range(15, 40):
                im.putpixel((x, y), (123, 55, 200))
        im.save(self.image)
        self.report = self.root / 'synthetic-provenance.json'
        self.write_report()

    def write_report(self, **overrides):
        data = dict(sha256=visual.ORIGINAL_JAR_SHA256, capture_sha256=visual.digest(self.image),
                    captured_from_live_emulator_process=True, emulator_sha256='test-emulator-only',
                    network_isolation='Linux network namespace (unshare -n)',
                    specific_historic_screen_verified=False)
        data.update(overrides)
        self.report.write_text(json.dumps(data))

    def review(self, kind='qeep-splash', confirmed=True):
        return visual.review_capture(self.image, self.report, self.root / 'review', kind,
                                     'Synthetic test image; not an authentic screenshot',
                                     confirmed, [10, 15, 20, 25])

    def test_review_classified_capture_and_compare(self):
        manifest = self.review()
        self.assertTrue(manifest['approved_for_pixel_comparison'])
        candidate = self.root / 'synthetic-love.png'
        # doubled pixels so logical comparison requires explicit 2x scale
        with Image.open(self.root / 'review/reference-reviewed.png') as img:
            img.resize((40, 50), Image.Resampling.NEAREST).save(candidate)
        r = visual.compare_reviewed(self.root / 'review/reference-review.json', candidate,
                                    self.root / 'diff', candidate_scale=2)
        self.assertTrue(r['pixel_identical'])
        self.assertEqual(r['classification'], 'qeep-splash')
        self.assertFalse(r['specific_historic_screen_verified_by_software'])
        self.assertTrue((self.root / 'diff/differences.png').exists())

    def test_reject_emulator_launcher_as_reference(self):
        self.review('emulator-ui', True)
        with self.assertRaisesRegex(ValueError, 'unreviewed'):
            visual.compare_reviewed(self.root / 'review/reference-review.json', self.image, self.root / 'diff')

    def test_no_implicit_human_approval(self):
        self.review('qeep-client', False)
        with self.assertRaisesRegex(ValueError, 'unreviewed'):
            visual.compare_reviewed(self.root / 'review/reference-review.json', self.image, self.root / 'diff')

    def test_reject_tampered_input_screenshot(self):
        self.write_report(capture_sha256='0' * 64)
        with self.assertRaisesRegex(ValueError, 'differs'):
            self.review()

    def test_reject_untrusted_jar_and_unisolated_capture(self):
        self.write_report(sha256='other')
        with self.assertRaisesRegex(ValueError, 'JAR hash'):
            self.review()
        self.write_report(network_isolation='not isolated')
        with self.assertRaisesRegex(ValueError, 'isolated'):
            self.review()

    def test_reject_invalid_crop(self):
        with self.assertRaisesRegex(ValueError, 'Crop outside'):
            visual.review_capture(self.image, self.report, self.root / 'review', 'qeep-client',
                                  'test', True, [60, 60, 100, 50])

    def test_reference_tampering_detected(self):
        self.review()
        with Image.open(self.root / 'review/reference-reviewed.png') as img:
            damaged = img.convert('RGB')
            damaged.putpixel((1, 1), (255, 0, 0))
            damaged.save(self.root / 'review/reference-reviewed.png')
        with self.assertRaisesRegex(ValueError, 'changed'):
            visual.compare_reviewed(self.root / 'review/reference-review.json', self.image, self.root / 'diff')

    def test_candidate_mismatch_dimensions_rejected(self):
        self.review()
        with self.assertRaisesRegex(ValueError, 'Canvas mismatch'):
            visual.compare_reviewed(self.root / 'review/reference-review.json', self.image, self.root / 'diff')


if __name__ == '__main__':
    unittest.main()
