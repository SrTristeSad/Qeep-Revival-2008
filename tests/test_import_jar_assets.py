#!/usr/bin/env python3
"""Offline validation of asset import safety, without bundling copyrighted PNGs."""
from pathlib import Path
import importlib.util
import tempfile
import zipfile

repo=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('import_jar_assets',repo/'tools/import_jar_assets.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
checks=0
with tempfile.TemporaryDirectory() as tmp:
    base=Path(tmp)
    archive=base/'fake.jar'
    with zipfile.ZipFile(archive,'w') as zipped:
        for name in module.EXPECTED:
            zipped.writestr(name,b'not the verified original')
    try:
        module.import_assets(archive,base/'output')
    except ValueError:
        checks+=1
    else:
        raise AssertionError('Tampered JAR accepted')
    assert not (base/'output').exists(), 'Partial import left files behind'
    checks+=1

assert len(module.EXPECTED)==3
checks+=1
print(f'OK: {checks} original asset importer safety checks')
