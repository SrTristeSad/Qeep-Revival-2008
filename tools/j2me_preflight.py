#!/usr/bin/env python3
"""Offline-first diagnostic for Qeep 1.29 in a Java ME emulator.

Does not fetch an emulator, execute the MIDlet, or contact legacy servers
unless --run-isolated is requested and Linux network isolation works.
"""
import argparse
import hashlib
import json
import platform
import shutil
import subprocess
from pathlib import Path
from zipfile import ZipFile


def inspect_midlet(jar):
    with ZipFile(jar) as z:
        manifest = z.read('META-INF/MANIFEST.MF').decode('latin-1')
        entries = {}
        for line in manifest.splitlines():
            if ':' in line and not line.startswith(' '):
                key, value = line.split(':', 1)
                entries[key] = value.strip()
        required = {
            'MIDlet-Name': 'qeep',
            'MIDlet-Version': '1.29',
            'MIDlet-Vendor': 'Blue Lion mobile',
            'MicroEdition-Profile': 'MIDP-2.0',
            'MicroEdition-Configuration': 'CLDC-1.0',
        }
        for field, expected in required.items():
            if entries.get(field) != expected:
                raise ValueError(f'Unexpected {field}: {entries.get(field)!r}')
        if 'joca/Joca.class' not in z.namelist():
            raise ValueError('MIDlet entry class missing')
        # A declared optional dynamic handler absent from this JAR does not
        # establish a valid, fully working client.
    return {
        'sha256': hashlib.sha256(jar.read_bytes()).hexdigest(),
        'midlet': entries['MIDlet-Name'],
        'version': entries['MIDlet-Version'],
        'profile': entries['MicroEdition-Profile'],
        'configuration': entries['MicroEdition-Configuration'],
        'startup_screen_verified': False,
        'network_safety': 'Do not allow the historic MIDlet to contact the public Internet.',
    }


def command_for(backend, emulator, original):
    if backend == 'freej2me':
        return ['java', '-jar', str(emulator), original.resolve().as_uri()]
    return ['java', '-jar', str(emulator), str(original.resolve())]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('jar', type=Path, help='the supplied qeep-94724.jar')
    ap.add_argument('--emulator', type=Path, help='local emulator JAR (not downloaded)')
    ap.add_argument('--backend', choices=['freej2me', 'microemulator'], default='freej2me')
    ap.add_argument('--report', type=Path, help='optional JSON provenance report')
    ap.add_argument('--run-isolated', action='store_true', help='Linux only: run with network namespace disabled; fails closed')
    args = ap.parse_args(argv)
    report = inspect_midlet(args.jar)
    report['emulator'] = str(args.emulator) if args.emulator else None
    report['backend'] = args.backend if args.emulator else None
    report['emulated'] = False
    report['captured'] = False
    command = None
    if args.emulator:
        if not args.emulator.is_file():
            raise ValueError('Emulator JAR missing')
        with ZipFile(args.emulator) as emulator_archive:
            if emulator_archive.testzip() is not None:
                raise ValueError('Emulator JAR corrupt')
        command = command_for(args.backend, args.emulator.resolve(), args.jar.resolve())
        report['proposed_command'] = command
    if args.run_isolated:
        if not command:
            ap.error('--run-isolated requires --emulator')
        if platform.system() != 'Linux' or not shutil.which('unshare'):
            ap.error('Isolated execution requires Linux unshare; emulator NOT started')
        probe = subprocess.run(['unshare', '-n', 'true'], capture_output=True)
        if probe.returncode != 0:
            ap.error('Network namespace unavailable; MIDlet NOT started')
        if not shutil.which('java'):
            ap.error('Java not installed; MIDlet NOT started')
        # The process remains inside a disconnected network namespace.
        report['emulated'] = True
        print('Launching inside isolated Linux network namespace, NO Internet access.', flush=True)
        ret = subprocess.call(['unshare', '-n'] + command)
        report['process_exit_code'] = ret
        report['emulated'] = ret == 0
        # GUI frame capture still requires user-supplied screenshot evidence.
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
