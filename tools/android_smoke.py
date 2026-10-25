#!/usr/bin/env python3
"""Install and launch the Qeep debug APK with adb; preserve emulator evidence."""
from __future__ import annotations
import argparse, json, re, subprocess, time
from pathlib import Path
DEFAULT_PACKAGE = 'com.srtristesad.qeeprevival2008'
DEFAULT_ACTIVITY = 'org.love2d.android.GameActivity'
PNG_HEADER = b'\x89PNG\r\n\x1a\n'
CRASH_MARKERS = ('FATAL EXCEPTION:', 'Fatal signal ', 'Unable to start activity',
                 'java.lang.UnsatisfiedLinkError', 'java.lang.NoClassDefFoundError')

def result_ok(start_output: str, pids: list[str], image: bytes, log: str, package: str):
    errors = []
    if 'Error type ' in start_output or 'Exception' in start_output or 'Error:' in start_output:
        errors.append('activity start reported error')
    if not pids or any(not re.fullmatch(r'\d+', pid.strip()) for pid in pids):
        errors.append('app process did not remain alive')
    if not image.startswith(PNG_HEADER) or len(image) < 100:
        errors.append('emulator screenshot missing or invalid')
    if any(marker in log for marker in CRASH_MARKERS):
        errors.append('Android crash signature in logcat')
    if package not in start_output:
        errors.append('launch output does not reference expected package')
    return not errors, errors

def adb(*args: str, timeout: int = 45, binary: bool = False):
    p = subprocess.run(['adb', *args], capture_output=True, timeout=timeout, check=False)
    if p.returncode:
        raise RuntimeError(f'adb {args[0]} failed: {p.stderr.decode(errors="replace")[:400]}')
    return p.stdout if binary else p.stdout.decode(errors='replace')

def smoke(apk: Path, output: Path, package: str, activity: str, seconds: int) -> bool:
    output.mkdir(parents=True, exist_ok=True)
    record = {'package': package, 'activity': activity, 'passed': False, 'errors': []}
    screenshot = b''
    log, start, pids = '', '', []
    try:
        if not apk.is_file() or apk.suffix.lower() != '.apk':
            raise ValueError('APK file missing')
        adb('wait-for-device', timeout=120)
        adb('install', '-r', str(apk), timeout=240)
        adb('logcat', '-c')
        start = adb('shell', 'am', 'start', '-W', '-n', f'{package}/{activity}', timeout=90)
        time.sleep(max(2, seconds // 2))
        first = adb('shell', 'pidof', '-s', package).strip()
        time.sleep(max(2, seconds - max(2, seconds // 2)))
        second = adb('shell', 'pidof', '-s', package).strip()
        pids = [first, second]
        screenshot = adb('exec-out', 'screencap', '-p', timeout=45, binary=True)
        log = adb('logcat', '-d', '-v', 'brief', timeout=45)
        record['passed'], record['errors'] = result_ok(start, pids, screenshot, log, package)
    except (RuntimeError, ValueError, subprocess.TimeoutExpired) as ex:
        record['errors'].append(str(ex)[:500])
        try: log = adb('logcat', '-d', '-v', 'brief', timeout=30)
        except (RuntimeError, subprocess.TimeoutExpired): pass
    finally:
        (output / 'launch.txt').write_text(start, encoding='utf-8')
        (output / 'logcat.txt').write_text(log, encoding='utf-8')
        if screenshot.startswith(PNG_HEADER):
            (output / 'emulator.png').write_bytes(screenshot)
        record['pids'] = pids
        record['screenshot_saved'] = screenshot.startswith(PNG_HEADER)
        (output / 'result.json').write_text(json.dumps(record, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    return record['passed']

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--apk', required=True, type=Path)
    p.add_argument('--output', default='android-smoke-results', type=Path)
    p.add_argument('--package', default=DEFAULT_PACKAGE)
    p.add_argument('--activity', default=DEFAULT_ACTIVITY)
    p.add_argument('--seconds', default=12, type=int)
    args = p.parse_args()
    ok = smoke(args.apk, args.output, args.package, args.activity, max(4,args.seconds))
    print('Emulator startup:', 'PASS' if ok else 'FAIL', '| evidence:', args.output)
    return 0 if ok else 1

if __name__ == '__main__':
    raise SystemExit(main())
