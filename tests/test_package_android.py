"""Tests for preparation of an embedded, debug-only Android 11.5a build."""
import io
from pathlib import Path
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import package_android as android


class AndroidPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.client = root / 'client'
        self.client.mkdir()
        (self.client / 'main.lua').write_text('function love.load() end\n', encoding='utf-8')
        (self.client / 'assets/original').mkdir(parents=True)
        (self.client / 'assets/original/logo.png').write_bytes(b'PRIVATE')
        self.upstream = root / 'upstream'
        (self.upstream / 'app/src/main').mkdir(parents=True)
        (self.upstream / 'app/src/embed/assets').mkdir(parents=True)
        (self.upstream / 'gradlew').write_text('#!/bin/sh\n')
        (self.upstream / 'gradle.properties').write_text(
            'app.name_byte_array=65,66\napp.application_id=org.love2d.android\n'
            'app.orientation=landscape\napp.version_code=32\napp.version_name=11.5a\n'
        )
        (self.upstream / 'app/build.gradle').write_text(
            "ndkVersion '25.2.9519653'\ncompileSdk 34\nproductFlavors { embed{} noRecord{} }\n"
            "def foo = 'embed'\ndef bar = 'noRecord'\n"
        )
        (self.upstream / 'app/src/main/AndroidManifest.xml').write_text(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">'
            '<uses-permission android:name="android.permission.INTERNET"/>'
            '<uses-permission android:name="android.permission.RECORD_AUDIO"/>'
            '<uses-permission android:name="android.permission.BLUETOOTH"/>'
            '<application android:allowBackup="true"/>'
            '</manifest>', encoding='utf-8'
        )

    def test_embedded_package_and_permissions(self):
        result = android.prepare(self.client, self.upstream)
        self.assertEqual(result['application_id'], android.APPLICATION_ID)
        game_file = self.upstream / 'app/src/embed/assets/game.love'
        with zipfile.ZipFile(game_file) as game:
            self.assertIn('main.lua', game.namelist())
            self.assertNotIn('assets/original/logo.png', game.namelist())
        props = (self.upstream / 'gradle.properties').read_text()
        self.assertIn('app.name=Qeep Revival 2008', props)
        self.assertIn('app.orientation=portrait', props)
        self.assertNotIn('app.name_byte_array=', props)
        self.assertEqual(props.count('app.application_id='), 1)
        xml = ET.parse(self.upstream / 'app/src/main/AndroidManifest.xml').getroot()
        ns = '{http://schemas.android.com/apk/res/android}'
        permissions = [x.get(ns+'name') for x in xml if x.tag == 'uses-permission']
        self.assertEqual(permissions, ['android.permission.INTERNET'])
        self.assertEqual(xml.find('application').get(ns+'allowBackup'), 'false')

    def test_rejects_unsupported_upstream(self):
        p = self.upstream / 'gradle.properties'
        p.write_text(p.read_text().replace('11.5a', '12.0'))
        with self.assertRaises(android.AndroidPackagingError):
            android.prepare(self.client, self.upstream)
        self.assertFalse((self.upstream / 'app/src/embed/assets/game.love').exists())

    def test_rejects_bad_source_structure(self):
        (self.upstream / 'app/build.gradle').unlink()
        with self.assertRaises(android.AndroidPackagingError):
            android.prepare(self.client, self.upstream)

    def test_rejects_bad_manifest(self):
        manifest = self.upstream / 'app/src/main/AndroidManifest.xml'
        manifest.write_text('<manifest><application /></manifest>')
        with self.assertRaises(android.AndroidPackagingError):
            android.prepare(self.client, self.upstream)

    def test_reproducible_embedded_bundle(self):
        first = android.prepare(self.client, self.upstream)['embedded_game_sha256']
        second = android.prepare(self.client, self.upstream)['embedded_game_sha256']
        self.assertEqual(first, second)

if __name__ == '__main__':
    unittest.main()
