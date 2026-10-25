"""Deterministic Windows bundling smoke tests. Uses a synthetic PE placeholder."""
from __future__ import annotations

import hashlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from package_windows import (PackagingError, build_love, make_distribution, runtime_files)


class WindowsPackagingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.client = self.root / 'client'
        (self.client / 'lib').mkdir(parents=True)
        (self.client / 'assets/original').mkdir(parents=True)
        (self.client / 'main.lua').write_text('function love.load() end\n')
        (self.client / 'conf.lua').write_text('function love.conf(t) end\n')
        (self.client / 'lib' / 'jcl.lua').write_text('return {}\n')
        (self.client / 'assets/original/logo.png').write_bytes(b'private')
        self.runtime = self.root / 'runtime.zip'
        self.expected = self.create_runtime()

    def create_runtime(self, evil=None, omit=None):
        with zipfile.ZipFile(self.runtime, 'w') as archive:
            for name in ['love.exe', 'love.dll', 'lua51.dll', 'SDL2.dll', 'OpenAL32.dll',
                         'license.txt', 'mpg123.dll']:
                if name == omit:
                    continue
                archive.writestr('love-11.5-win64/' + name, b'MZ' if name.endswith('exe') else name.encode())
            if evil:
                archive.writestr(evil, b'evil')
        return hashlib.sha256(self.runtime.read_bytes()).hexdigest()

    def test_private_original_art_excluded(self):
        with zipfile.ZipFile(io.BytesIO(build_love(self.client))) as archive:
            self.assertEqual(archive.namelist(), ['conf.lua', 'lib/jcl.lua', 'main.lua'])

    def test_fused_package_and_reproducibility(self):
        first_zip = self.root / 'windows1.zip'
        first_love = self.root / 'client1.love'
        second_zip = self.root / 'windows2.zip'
        second_love = self.root / 'client2.love'
        make_distribution(self.client, self.runtime, self.expected, first_zip, first_love)
        make_distribution(self.client, self.runtime, self.expected, second_zip, second_love)
        self.assertEqual(first_zip.read_bytes(), second_zip.read_bytes())
        self.assertEqual(first_love.read_bytes(), second_love.read_bytes())
        with zipfile.ZipFile(first_zip) as archive:
            names = archive.namelist()
            self.assertIn('QeepRevival2008/QeepRevival2008.exe', names)
            self.assertIn('QeepRevival2008/love.dll', names)
            self.assertIn('QeepRevival2008/license.txt', names)
            self.assertNotIn('QeepRevival2008/love.exe', names)
            with zipfile.ZipFile(io.BytesIO(archive.read('QeepRevival2008/QeepRevival2008.exe'))) as fused:
                self.assertIn('main.lua', fused.namelist())
                self.assertNotIn('assets/original/logo.png', fused.namelist())

    def test_sha256_required(self):
        with self.assertRaisesRegex(PackagingError, 'SHA-256'):
            runtime_files(self.runtime, '0' * 64)

    def test_runtime_zip_path_traversal_rejected(self):
        expected = self.create_runtime(evil='../bad.exe')
        with self.assertRaisesRegex(PackagingError, 'Unsafe entry'):
            runtime_files(self.runtime, expected)

    def test_missing_required_runtime_files(self):
        expected = self.create_runtime(omit='lua51.dll')
        with self.assertRaisesRegex(PackagingError, 'Required LÖVE'):
            runtime_files(self.runtime, expected)

    def test_disallow_client_symlinks(self):
        link = self.client / 'link.lua'
        try:
            link.symlink_to(self.client / 'main.lua')
        except (NotImplementedError, OSError):
            self.skipTest('Symlinks not available on this system')
        with self.assertRaisesRegex(PackagingError, 'Symlinks'):
            build_love(self.client)

    def test_explicit_personal_original_assets(self):
        with zipfile.ZipFile(io.BytesIO(build_love(self.client, True))) as archive:
            self.assertIn('assets/original/logo.png', archive.namelist())


if __name__ == '__main__':
    unittest.main()
