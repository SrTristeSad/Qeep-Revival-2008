#!/usr/bin/env python3
"""Audit reproducible graphic evidence in the user-provided Qeep 1.29 JAR.

Does not execute the MIDlet, connect to a service, or extract copyrighted
image bytes. Can optionally emit a JSON evidence report without assets.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile
from import_jar_assets import EXPECTED

SWATCHES = {
    's0': ('bg', 'ebffb9'),
    's2': ('bg', 'cdff3c'),
    's7': ('cbg', 'a0b419'),
    's10': ('bg', 'a1b617'),
    's11': ('tc', '3c143c'),
}
COMMANDS = {'back.cmd': 'Back', 'kui.cmd.select': 'Select',
            'kui.cmd.cancel': 'Cancel', 'kui.cmd.options': 'Options',
            'ok.cmd': 'OK'}


def entries_from_registry(data):
    entries = {}
    for line in data.decode('latin-1').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            entries[key.strip()] = value.strip()
    return entries


def inspect(jar):
    with zipfile.ZipFile(jar) as archive:
        reg_data = archive.read('registry.ini')
        entries = entries_from_registry(reg_data)
        if entries.get('filename') != 'qeep_en-1.29':
            raise ValueError('Not the expected English Qeep 1.29 release')
        for key, expected in COMMANDS.items():
            if entries.get(key) != expected:
                raise ValueError(f'Unexpected command {key}: {entries.get(key)}')
        for key, (attr, expected) in SWATCHES.items():
            value = entries.get(key, '')
            parts = dict((segment.split(':', 1) for segment in value.split(';')
                          if ':' in segment))
            actual = parts.get(attr, '').split(',')[-1].lower()
            if actual != expected:
                raise ValueError(f'Unexpected registry color {key}.{attr}: {actual}')
        images = {}
        for name, (expected_sha, expected_size) in EXPECTED.items():
            binary = archive.read(name)
            actual_sha = hashlib.sha256(binary).hexdigest()
            size = struct.unpack('>II', binary[16:24]) if binary[:8] == b'\x89PNG\r\n\x1a\n' else None
            if actual_sha != expected_sha or size != expected_size:
                raise ValueError(f'Wrong SHA-256 or dimensions for {name}')
            images[name] = {'sha256': actual_sha, 'width': size[0], 'height': size[1]}
        return {
            'source': 'user-supplied qeep-94724.jar / registry.ini / PNG headers',
            'version': entries['filename'],
            'commands': COMMANDS,
            'colors': {f'{key}.{attr}': expected for key, (attr, expected) in SWATCHES.items()},
            'images': images,
            'screens_recovered': False,
            'note': 'Asset/registry evidence only; historical server pages are absent.'
        }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jar', type=Path)
    parser.add_argument('--output', type=Path)
    args=parser.parse_args()
    report=inspect(args.jar)
    rendered=json.dumps(report, indent=2, ensure_ascii=False) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding='utf-8')
    print(rendered, end='')


if __name__ == '__main__':
    main()
