#!/usr/bin/env python3
"""Offline, static integrity audit of the standalone Windows x64 distribution.

This validates packaging but does NOT claim to launch a real graphical Windows app.
"""
from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path
import struct
import zipfile

PREFIX = 'QeepRevival2008/'
REQUIRED = {'QeepRevival2008.exe', 'love.dll', 'lua51.dll', 'SDL2.dll', 'license.txt'}

class WindowsBundleError(ValueError):
    pass


def check_pe_x64(data: bytes) -> None:
    if len(data) < 0x100 or data[:2] != b'MZ':
        raise WindowsBundleError('EXE has no DOS header')
    offset = struct.unpack_from('<I', data, 0x3c)[0]
    if offset+6 > len(data) or data[offset:offset+4] != b'PE\x00\x00':
        raise WindowsBundleError('EXE has no PE header')
    if struct.unpack_from('<H', data, offset+4)[0] != 0x8664:
        raise WindowsBundleError('EXE is not AMD64')


def verify(bundle: Path) -> dict[str, int]:
    with zipfile.ZipFile(bundle) as outer:
        file_set = set(outer.namelist())
        expected = {PREFIX + name for name in REQUIRED}
        if not expected.issubset(file_set):
            raise WindowsBundleError('Runtime DLL, EXE, or license missing')
        if len(file_set) != len(outer.namelist()):
            raise WindowsBundleError('Duplicate entries in Windows ZIP')
        if any(not name.startswith(PREFIX) or '..' in name.split('/') for name in file_set):
            raise WindowsBundleError('Unexpected path in Windows ZIP')
        for member in outer.infolist():
            if not member.is_dir() and member.CRC != (zipfile.crc32(outer.read(member)) & 0xffffffff):
                raise WindowsBundleError('Corrupt member in Windows bundle')
        exe = outer.read(PREFIX+'QeepRevival2008.exe')
    check_pe_x64(exe)
    with zipfile.ZipFile(BytesIO(exe)) as game:
        if 'main.lua' not in game.namelist():
            raise WindowsBundleError('Fused EXE has no client main.lua')
        if any(p.startswith('assets/original/') for p in game.namelist()):
            raise WindowsBundleError('Public bundle contains original Qeep art')
        game.read('main.lua')
        total = len(game.namelist())
    return {'windows_files': len(file_set), 'embedded_client_files': total}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle',type=Path)
    args=parser.parse_args()
    try:
        print(verify(args.bundle))
    except (WindowsBundleError, OSError, zipfile.BadZipFile) as exc:
        parser.exit(1, f'Windows bundle verification failed: {exc}\n')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
