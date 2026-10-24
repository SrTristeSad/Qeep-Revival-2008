#!/usr/bin/env python3
"""Import three verified PNG resources from the user's Qeep 1.29 JAR.

Assets remain local/ignored by Git; no online source or legacy login needed.
"""
from pathlib import Path
import argparse
import hashlib
import struct
import sys
import zipfile

EXPECTED = {
    'logo.png': ('6e8c1ab01588fd87e634a3cd673c06a69d2706e7fe32ef1683ba30809d630b23', (128, 42)),
    'icon_15x15.png': ('50e658d46dc33240ae9d9f46e25e59473da9fbbd428095882529a6e942040e0d', (15, 15)),
    'kui/symbols.png': ('37c96b453c4711aee5f7de7dd7d1b0499f07bdb02815e8f69bc51573e7b08cf0', (12, 180)),
}


def import_assets(jar: Path, dest: Path, overwrite=False):
    validated=[]
    with zipfile.ZipFile(jar) as source:
        for name, (digest, size) in EXPECTED.items():
            data=source.read(name)
            if hashlib.sha256(data).hexdigest() != digest:
                raise ValueError(f'Unrecognized resource (SHA-256 mismatch): {name}')
            if len(data)<24 or data[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II',data[16:24]) != size:
                raise ValueError(f'Unrecognized PNG dimensions: {name}')
            output=dest/name
            if output.exists() and not overwrite and output.read_bytes()!=data:
                raise FileExistsError(f'Existing file differs; use --overwrite: {output}')
            validated.append((output,data))
    extracted=[]
    # Validate every resource before writing any file; mismatches do not create
    # a half-imported asset set.
    for output,data in validated:
        output.parent.mkdir(parents=True,exist_ok=True)
        output.write_bytes(data)
        extracted.append(str(output))
    return extracted



def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('jar',type=Path,help='Original qeep-94724.jar')
    parser.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'client/assets/original')
    parser.add_argument('--overwrite',action='store_true')
    args=parser.parse_args(argv)
    for path in import_assets(args.jar,args.output,args.overwrite):
        print(path)
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except (OSError,ValueError,zipfile.BadZipFile,KeyError) as e:
        sys.exit(f'Import failed: {e}')
