#!/usr/bin/env python3
"""Review a capture from j2me_capture.py, then compare it against a LÖVE capture.

Capture provenance is self-reported by the runner and hash-bound to the pixels;
this tool does NOT prove visually that a historic screen was displayed. Review
requires explicit human classification; emulator UI/unknown images are rejected
for comparisons. No original JAR or captured private data are uploaded.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
from compare_visual import crop_and_normalize, compare

ORIGINAL_JAR_SHA256 = 'fd24b6191fbef801f3b7791def8c9c13e30485c9152fe073799f46c383e5e6b3'
APP_CLASSES = {'qeep-splash', 'qeep-client', 'qeep-error'}
ALL_CLASSES = sorted(APP_CLASSES | {'emulator-ui', 'unknown'})


def digest(path):
    d = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            d.update(block)
    return d.hexdigest()


def load_json(path):
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise ValueError('Manifest must be a JSON object')
    return data


def check_provenance(image, report):
    """Checks consistency of supplied evidence, NOT authenticity of a screenshot."""
    if report.get('sha256') != ORIGINAL_JAR_SHA256:
        raise ValueError('Original JAR hash does not match Qeep 1.29')
    if report.get('capture_sha256') != digest(image):
        raise ValueError('Screenshot SHA-256 differs from the emulator capture report')
    if report.get('captured_from_live_emulator_process') is not True:
        raise ValueError('The report does not claim a live emulator process')
    if report.get('network_isolation') != 'Linux network namespace (unshare -n)':
        raise ValueError('Missing isolated-execution assertion')
    if report.get('specific_historic_screen_verified') is not False:
        raise ValueError('Unexpected historical verification claim in raw report')
    if not report.get('emulator_sha256'):
        raise ValueError('No emulator hash recorded')


def check_crop(image_size, crop):
    if not crop:
        raise ValueError('Explicit screenshot crop is required (x y width height)')
    x, y, w, h = crop
    if min(x, y) < 0 or w <= 0 or h <= 0 or x + w > image_size[0] or y + h > image_size[1]:
        raise ValueError('Crop outside reference screenshot')
    return [x, y, w, h]


def review_capture(image_path, provenance_path, output_dir, classification, note, confirmed, crop):
    if classification not in ALL_CLASSES:
        raise ValueError('Unsupported screen classification')
    if not note or not note.strip():
        raise ValueError('Reviewer note is required; describe what can be seen')
    image_path = Path(image_path)
    provenance_path = Path(provenance_path)
    output_dir = Path(output_dir)
    report = load_json(provenance_path)
    check_provenance(image_path, report)
    with Image.open(image_path) as f:
        f.verify()  # reject malformed PNG before writing output
    with Image.open(image_path) as f:
        if f.format != 'PNG':
            raise ValueError('Expected PNG image from capture runner')
        crop = check_crop(f.size, crop)
        normalized = crop_and_normalize(f, crop=crop)
    # Human confirmation is required to classify a real Qeep screen.
    allowed = classification in APP_CLASSES and confirmed is True
    output_dir.mkdir(parents=True, exist_ok=True)
    cropped_path = output_dir / 'reference-reviewed.png'
    normalized.save(cropped_path)
    manifest = {
        'schema_version': 1,
        'classification': classification,
        'reviewer_note': note.strip(),
        'reviewer_confirmed_visible_app': bool(confirmed),
        'approved_for_pixel_comparison': allowed,
        'original_jar_sha256': report['sha256'],
        'emulator_sha256': report['emulator_sha256'],
        'original_screenshot_sha256': report['capture_sha256'],
        'original_screenshot_path': str(image_path.resolve()),
        'emulator_report_path': str(provenance_path.resolve()),
        'reviewed_screenshot_path': str(cropped_path.resolve()),
        'reviewed_screenshot_sha256': digest(cropped_path),
        'crop_original_xywh': crop,
        'reviewed_screenshot_size': list(normalized.size),
        'note': 'Human review only; hashes guard file consistency, not historical authenticity. An offline Qeep splash/error is not proof of remote social pages.',
    }
    (output_dir / 'reference-review.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return manifest


def compare_reviewed(manifest_path, candidate_path, output_dir, candidate_crop=None, candidate_scale=1):
    manifest = load_json(Path(manifest_path))
    if manifest.get('schema_version') != 1 or manifest.get('approved_for_pixel_comparison') is not True:
        raise ValueError('Reference is unreviewed or not an explicitly confirmed Qeep screen')
    if manifest.get('classification') not in APP_CLASSES:
        raise ValueError('Emulator/unknown screens cannot be used as Qeep comparison reference')
    if manifest.get('original_jar_sha256') != ORIGINAL_JAR_SHA256:
        raise ValueError('Unexpected original JAR hash in review')
    reviewed_path = Path(manifest['reviewed_screenshot_path'])
    if digest(reviewed_path) != manifest.get('reviewed_screenshot_sha256'):
        raise ValueError('Reviewed reference screenshot changed after review')
    with Image.open(reviewed_path) as f:
        reference = crop_and_normalize(f)
    with Image.open(candidate_path) as f:
        candidate = crop_and_normalize(f, candidate_crop, candidate_scale)
    result = compare(reference, candidate)
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    result.pop('heatmap').save(output_dir / 'differences.png')
    result.pop('overlay').save(output_dir / 'overlay.png')
    reference.save(output_dir / 'reference.png')
    candidate.save(output_dir / 'candidate.png')
    findings = {
        **result,
        'reference_review_path': str(Path(manifest_path).resolve()),
        'reference_sha256': manifest['reviewed_screenshot_sha256'],
        'candidate_sha256': digest(Path(candidate_path)),
        'classification': manifest['classification'],
        'specific_historic_screen_verified_by_software': False,
        'note': 'Numeric pixel comparison of human-reviewed reference; matching screen identity is not automatically established.'
    }
    (output_dir / 'report.json').write_text(json.dumps(findings, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return findings


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest='action', required=True)
    r = sub.add_parser('review', help='Classify and crop a real emulator PNG with its capture provenance')
    r.add_argument('screenshot', type=Path)
    r.add_argument('capture_report', type=Path)
    r.add_argument('--classification', choices=ALL_CLASSES, required=True)
    r.add_argument('--note', required=True, help='visible UI and reason for classification')
    r.add_argument('--confirm-visible-app', action='store_true', help='human review confirms this is Qeep, not merely emulator UI')
    r.add_argument('--crop', type=int, nargs=4, metavar=('X', 'Y', 'W', 'H'), required=True)
    r.add_argument('--out-dir', type=Path, default=Path('visual-results/review'))
    c = sub.add_parser('compare', help='Compare a human-reviewed Qeep reference with a matching LÖVE screenshot')
    c.add_argument('review_manifest', type=Path)
    c.add_argument('candidate', type=Path)
    c.add_argument('--candidate-crop', nargs=4, type=int, metavar=('X', 'Y', 'W', 'H'))
    c.add_argument('--candidate-scale', type=int, default=1)
    c.add_argument('--out-dir', type=Path, default=Path('visual-results/review-comparison'))
    args = ap.parse_args(argv)
    if args.action == 'review':
        result = review_capture(args.screenshot, args.capture_report, args.out_dir, args.classification,
                                args.note, args.confirm_visible_app, args.crop)
    else:
        result = compare_reviewed(args.review_manifest, args.candidate, args.out_dir,
                                  args.candidate_crop, args.candidate_scale)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        print(f'Evidence rejected: {exc}', file=__import__('sys').stderr)
        raise SystemExit(2)
