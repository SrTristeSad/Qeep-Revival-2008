#!/usr/bin/env python3
"""Capture an actual Java ME emulator window in a fresh Xvfb display.

The historic Qeep MIDlet MUST never access the Internet: this runner refuses to
launch without a working Linux network namespace (`unshare -n`). A screenshot
establishes pixels from an emulator process, not that the MIDlet reached a
particular historical network-delivered page.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
from zipfile import BadZipFile, ZipFile

from j2me_preflight import inspect_midlet, command_for

EXPECTED_SHA = 'fd24b6191fbef801f3b7791def8c9c13e30485c9152fe073799f46c383e5e6b3'


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def validate_inputs(jar, emulator, backend, allow_other_jar=False):
    if not jar.is_file() or not emulator.is_file():
        raise ValueError('JAR original e emulador devem existir localmente')
    preflight = inspect_midlet(jar)
    if not allow_other_jar and preflight['sha256'] != EXPECTED_SHA:
        raise ValueError('O SHA-256 não corresponde ao qeep-94724.jar enviado; captura recusada')
    try:
        with ZipFile(emulator) as archive:
            if archive.testzip() is not None or 'META-INF/MANIFEST.MF' not in archive.namelist():
                raise ValueError('Emulador JAR inválido')
            if backend == 'microemulator' and 'org/microemu/app/Main.class' not in archive.namelist():
                raise ValueError('O arquivo não parece conter o MicroEmulator')
    except BadZipFile as error:
        raise ValueError('Arquivo de emulador não é ZIP/JAR válido') from error
    return dict(preflight, emulator_sha256=sha256_file(emulator),
                backend=backend, emulator=str(emulator.resolve()),
                original_jar=str(jar.resolve()))


def check_isolation():
    if platform.system() != 'Linux':
        raise RuntimeError('Captura automática isolada suportada somente no Linux')
    for name in ('java', 'unshare', 'Xvfb'):
        if not shutil.which(name):
            raise RuntimeError(f'Dependência ausente: {name}')
    probe = subprocess.run(['unshare', '-n', '--', 'true'], capture_output=True, timeout=5)
    if probe.returncode != 0:
        raise RuntimeError('Sem permissão para unshare -n; JAR NÃO foi executado. '
                           'Use um Linux com namespaces habilitados.')


def free_display():
    for number in range(90, 200):
        if not Path(f'/tmp/.X11-unix/X{number}').exists() and not Path(f'/tmp/.X{number}-lock').exists():
            return f':{number}'
    raise RuntimeError('Sem tela X virtual disponível')


def create_report(info, screenshot, *, live, exit_code, duration, command):
    """Never assert that a particular historic page loaded automatically."""
    result = dict(info)
    result.update({
        'capture_path': str(screenshot.resolve()),
        'capture_sha256': sha256_file(screenshot),
        'captured_from_live_emulator_process': bool(live),
        'emulator_exit_code_at_capture': exit_code,
        'elapsed_seconds': round(duration, 3),
        'network_isolation': 'Linux network namespace (unshare -n)',
        'launch_command': command,
        'specific_historic_screen_verified': False,
        'manual_visual_review_required': True,
        'warning': 'Screenshot can contain an emulator launcher, an error, or an incomplete splash; do not mark it as an authenticated Qeep screen until reviewed.',
    })
    return result


def run_capture(info, jar, emulator, backend, destination, delay, display):
    from PIL import ImageGrab
    check_isolation()  # fail CLOSED before invoking anything from the historical JAR
    destination.mkdir(parents=True, exist_ok=True)
    screen = display or free_display()
    env = dict(os.environ, DISPLAY=screen)
    log_path = destination / 'emulator.log'
    xvfb = subprocess.Popen(['Xvfb', screen, '-screen', '0', '800x640x24', '-nolisten', 'tcp'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    emulator_process = None
    try:
        time.sleep(0.5)
        if xvfb.poll() is not None:
            raise RuntimeError('Xvfb encerrou antes da captura')
        cmd = ['unshare', '-n', '--'] + command_for(backend, emulator, jar)
        start = time.monotonic()
        with open(log_path, 'w', encoding='utf-8') as log:
            emulator_process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, env=env)
            time.sleep(delay)
            live = emulator_process.poll() is None
            if not live:
                raise RuntimeError(f'Emulador encerrou antes da captura: {emulator_process.returncode}; consulte emulator.log')
            # Capture the dedicated, empty-by-design display. No desktop/user windows are involved.
            image = ImageGrab.grab(xdisplay=screen)
            image_path = destination / 'emulator-window.png'
            image.save(image_path)
        report = create_report(info, image_path, live=live,
                               exit_code=emulator_process.poll(),
                               duration=time.monotonic() - start, command=cmd)
        (destination / 'capture-provenance.json').write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        return report
    finally:
        if emulator_process and emulator_process.poll() is None:
            emulator_process.terminate()
            try:
                emulator_process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                emulator_process.kill()
                emulator_process.wait()
        if xvfb.poll() is None:
            xvfb.terminate()
            xvfb.wait(timeout=5)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('jar', type=Path, help='arquivo qeep-94724.jar original')
    ap.add_argument('--emulator', type=Path, required=True, help='JAR local do MicroEmulator/FreeJ2ME')
    ap.add_argument('--backend', choices=('microemulator', 'freej2me'), default='microemulator')
    ap.add_argument('--out-dir', type=Path, default=Path('visual-results/emulator'))
    ap.add_argument('--delay', type=float, default=8, help='segundos entre início e captura (1..60)')
    ap.add_argument('--display', help='display Xvfb explícito, por exemplo :99')
    ap.add_argument('--run-isolated', action='store_true', help='execução real: exige unshare -n funcional')
    args = ap.parse_args(argv)
    if not (1 <= args.delay <= 60):
        ap.error('--delay precisa estar entre 1 e 60 segundos')
    info = validate_inputs(args.jar, args.emulator, args.backend)
    info.update(execution_requested=args.run_isolated,
                capture_performed=False,
                proposed_command=['unshare', '-n', '--'] + command_for(args.backend, args.emulator, args.jar))
    if not args.run_isolated:
        print(json.dumps(info, indent=2, ensure_ascii=False))
        return 0
    result = run_capture(info, args.jar, args.emulator, args.backend,
                         args.out_dir, args.delay, args.display)
    result['capture_performed'] = True
    (args.out_dir / 'capture-provenance.json').write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, RuntimeError, OSError) as error:
        print('Captura recusada: ' + str(error), file=sys.stderr)
        sys.exit(2)