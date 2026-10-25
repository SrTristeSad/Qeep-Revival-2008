#!/usr/bin/env python3
"""Compare two *provided* screenshots at logical pixel size.

Never creates a purported historic screenshot. The provenance of the two
inputs must be recorded separately. Requires Pillow (pip install Pillow).
"""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageChops


def crop_and_normalize(image, crop=None, scale=1):
    if scale < 1 or int(scale) != scale:
        raise ValueError('Scale must be a positive integer')
    image = image.convert('RGBA')
    if crop:
        x, y, width, height = crop
        if min(x, y) < 0 or width <= 0 or height <= 0 or x + width > image.width or y + height > image.height:
            raise ValueError('Crop outside screenshot')
        image = image.crop((x, y, x + width, y + height))
    if image.width % scale or image.height % scale:
        raise ValueError('Image dimensions are not divisible by pixel scale')
    if scale != 1:
        # Nearest-neighbour: do not invent/interpolate pixels in screenshot.
        image = image.resize((image.width // scale, image.height // scale), Image.Resampling.NEAREST)
    return Image.alpha_composite(Image.new('RGBA', image.size, 'white'), image).convert('RGB')


def compare(reference, candidate, masks=()):
    if reference.size != candidate.size:
        raise ValueError(f'Canvas mismatch {reference.size} vs {candidate.size}; use explicit crops/scales')
    a = reference.copy()
    b = candidate.copy()
    valid = bytearray(b'\x01') * (a.width * a.height)
    for x, y, width, height in masks:
        if min(x, y) < 0 or width <= 0 or height <= 0 or x + width > a.width or y + height > a.height:
            raise ValueError('Mask outside logical canvas')
        for yy in range(y, y + height):
            valid[yy*a.width+x: yy*a.width+x+width] = b'\x00' * width
    pa = a.load(); pb = b.load()
    heatmap = Image.new('RGB', a.size, (0, 0, 0))
    ph = heatmap.load()
    changed = errors = considered = 0
    for y in range(a.height):
        for x in range(a.width):
            if not valid[y*a.width+x]:
                ph[x, y] = (55, 55, 55)
                continue
            considered += 1
            err = sum(abs(pa[x, y][i] - pb[x, y][i]) for i in range(3))
            errors += err
            if err:
                changed += 1
                ph[x, y] = (min(255, err), 0, 0)
    if not considered:
        raise ValueError('All pixels masked; no comparison possible')
    return {
        'size': list(a.size),
        'pixels_checked': considered,
        'pixels_changed': changed,
        'changed_percent': round(changed * 100 / considered, 4),
        'mean_absolute_error_rgb': round(errors / (considered * 3), 4),
        'pixel_identical': changed == 0,
        'heatmap': heatmap,
        'overlay': Image.blend(a, b, 0.5),
    }


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('reference', type=Path, help='real emulator capture, supplied explicitly')
    p.add_argument('candidate', type=Path, help='LÖVE client screenshot')
    p.add_argument('--crop-reference', nargs=4, type=int, metavar=('X','Y','W','H'))
    p.add_argument('--crop-candidate', nargs=4, type=int, metavar=('X','Y','W','H'))
    p.add_argument('--scale-reference', type=int, default=1)
    p.add_argument('--scale-candidate', type=int, default=1)
    p.add_argument('--mask', nargs=4, type=int, action='append', default=[], metavar=('X','Y','W','H'))
    p.add_argument('--out-dir', type=Path, default=Path('visual-results'))
    p.add_argument('--assert-identical', action='store_true')
    args = p.parse_args(argv)
    with Image.open(args.reference) as original, Image.open(args.candidate) as revival:
        a = crop_and_normalize(original, args.crop_reference, args.scale_reference)
        b = crop_and_normalize(revival, args.crop_candidate, args.scale_candidate)
    result = compare(a, b, args.mask)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    a.save(args.out_dir / 'reference-normalized.png')
    b.save(args.out_dir / 'candidate-normalized.png')
    result.pop('heatmap').save(args.out_dir / 'differences.png')
    result.pop('overlay').save(args.out_dir / 'overlay.png')
    report = dict(result, reference_path=str(args.reference), candidate_path=str(args.candidate),
                  masks=args.mask, historical_capture_verified_by_tool=False,
                  note='Tool compares pixels only; historic authenticity must be established separately.')
    (args.out_dir / 'report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
    return 1 if args.assert_identical and not result['pixel_identical'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
