"""Static checks; does not simulate launching a Windows GUI process."""
import io
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import verify_windows_bundle as checker

class WinBundleTests(unittest.TestCase):
    def make_bundle(self, root: Path, machine=0x8664, logo=False, missing=None):
        program=bytearray(256)
        program[:2]=b'MZ'
        struct.pack_into('<I',program,0x3c,128)
        program[128:132]=b'PE\0\0'
        struct.pack_into('<H',program,132,machine)
        game=io.BytesIO()
        with zipfile.ZipFile(game,'w') as z:
            z.writestr('main.lua','function love.load() end')
            if logo:
                z.writestr('assets/original/logo.png','non-public')
        exe=bytes(program)+game.getvalue()
        archive=root/'bundle.zip'
        with zipfile.ZipFile(archive,'w') as z:
            for name in sorted(checker.REQUIRED):
                if name != missing:
                    z.writestr(checker.PREFIX+name,exe if name.endswith('.exe') else b'DLL or license')
        return archive

    def test_good_structure(self):
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(checker.verify(self.make_bundle(Path(t)))['embedded_client_files'],1)

    def test_wrong_pe_architecture(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaisesRegex(checker.WindowsBundleError,'AMD64'):
                checker.verify(self.make_bundle(Path(t),machine=0x14c))

    def test_missing_runtime(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaisesRegex(checker.WindowsBundleError,'missing'):
                checker.verify(self.make_bundle(Path(t),missing='love.dll'))

    def test_original_assets_rejected(self):
        with tempfile.TemporaryDirectory() as t:
            with self.assertRaisesRegex(checker.WindowsBundleError,'original'):
                checker.verify(self.make_bundle(Path(t),logo=True))

    def test_actual_fase20_bundle_when_present(self):
        p=Path('/mnt/data/Qeep-Revival-2008-Windows-x64.zip')
        if p.is_file():
            self.assertGreater(checker.verify(p)['embedded_client_files'],10)

if __name__=='__main__':
    unittest.main()
