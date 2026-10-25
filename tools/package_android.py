#!/usr/bin/env python3
"""Prepare the OFFICIAL LÖVE Android 11.5a source tree to build a private debug APK.

This never downloads, signs, or runs Gradle. An upstream source checkout is required.
Native libraries are built by upstream Gradle; the Qeep Revival Lua client is embedded
as assets/game.love. Neither original JAR resources nor private databases are bundled.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

from package_windows import build_love

APPLICATION_ID = 'com.srtristesad.qeeprevival2008'
APP_NAME = 'Qeep Revival 2008'
VERSION_NAME = '0.21.0-test'
VERSION_CODE = '21'
ANDROID_NS = '{http://schemas.android.com/apk/res/android}'
ALLOWED_PERMISSIONS = {'android.permission.INTERNET'}
UPSTREAM_TAG = '11.5a'
UPSTREAM_COMMIT = '55feb38fa144f4734c26742389f279fb07d955c0'

class AndroidPackagingError(ValueError):
    pass


def verify_upstream(tree: Path) -> None:
    needed = [tree / 'gradlew', tree / 'gradle.properties', tree / 'app/build.gradle',
              tree / 'app/src/main/AndroidManifest.xml']
    if not all(p.is_file() for p in needed):
        raise AndroidPackagingError('Expected a complete love2d/love-android checkout')
    gradle = (tree / 'app/build.gradle').read_text(encoding='utf-8')
    if not re.search(r'\bembed\s*\{', gradle) or not re.search(r'\bnoRecord\s*\{', gradle):
        raise AndroidPackagingError('Unsupported upstream Android flavors')
    if "25.2.9519653" not in gradle or 'compileSdk 34' not in gradle:
        raise AndroidPackagingError('Unsupported Android version; expected LÖVE 11.5a')
    props = (tree / 'gradle.properties').read_text(encoding='utf-8')
    if not re.search(r'^app.version_name=(11\.5a|0\.21\.0-test)\s*$', props, re.M):
        raise AndroidPackagingError('Wrong LÖVE Android version (expected 11.5a)')


def update_properties(contents: str) -> str:
    target = {
        'app.name': APP_NAME, 'app.application_id': APPLICATION_ID,
        'app.orientation': 'portrait', 'app.version_code': VERSION_CODE,
        'app.version_name': VERSION_NAME,
    }
    lines = []
    for line in contents.splitlines():
        match = re.match(r'^\s*#?\s*(app\.[A-Za-z0-9_]+)\s*=', line)
        if match and match.group(1) in {*target, 'app.name_byte_array'}:
            continue
        lines.append(line)
    lines.extend(f'{key}={value}' for key, value in target.items())
    return '\n'.join(lines) + '\n'


def reduce_permissions(manifest: Path) -> None:
    ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
    tree = ET.parse(manifest)
    root = tree.getroot()
    if root.tag != 'manifest':
        raise AndroidPackagingError('Unexpected upstream manifest')
    for node in list(root):
        if node.tag in {'uses-permission', 'uses-permission-sdk-23'}:
            if node.get(ANDROID_NS+'name') not in ALLOWED_PERMISSIONS:
                root.remove(node)
    if not any(child.tag == 'uses-permission' and child.get(ANDROID_NS+'name') ==
               'android.permission.INTERNET' for child in root):
        raise AndroidPackagingError('INTERNET permission is needed for LAN chat')
    app = root.find('application')
    if app is None:
        raise AndroidPackagingError('Missing application element')
    app.set(ANDROID_NS+'allowBackup', 'false')
    tree.write(manifest, encoding='utf-8', xml_declaration=True)


def prepare(client: Path, upstream: Path) -> dict[str, str]:
    upstream = upstream.resolve(strict=True)
    verify_upstream(upstream)
    game = build_love(client, include_original_assets=False)
    from io import BytesIO
    from zipfile import ZipFile
    with ZipFile(BytesIO(game)) as archive:
        names = archive.namelist()
        if 'main.lua' not in names or any(p.startswith('assets/original/') for p in names):
            raise AndroidPackagingError('Invalid client bundle or original assets detected')
    gradle_properties = upstream / 'gradle.properties'
    manifest = upstream / 'app/src/main/AndroidManifest.xml'
    new_props = update_properties(gradle_properties.read_text(encoding='utf-8'))
    # Write the game and patched Android metadata only after input validation.
    gradle_properties.write_text(new_props, encoding='utf-8')
    reduce_permissions(manifest)
    game_path = upstream / 'app/src/embed/assets/game.love'
    game_path.parent.mkdir(parents=True, exist_ok=True)
    game_path.write_bytes(game)
    return {'upstream_tag': UPSTREAM_TAG, 'expected_upstream_commit': UPSTREAM_COMMIT,
            'application_id': APPLICATION_ID, 'embedded_game_sha256': hashlib.sha256(game).hexdigest()}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--client', type=Path, default=Path('client'))
    parser.add_argument('--love-android', type=Path, required=True)
    args = parser.parse_args()
    try:
        values = prepare(args.client, args.love_android)
    except (AndroidPackagingError, OSError, ET.ParseError, ValueError) as error:
        parser.exit(1, f'Android package preparation failed: {error}\n')
    for k, value in values.items():
        print(f'{k}={value}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
