import json, re, unittest, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

class RegistryTests(unittest.TestCase):
 def test_snapshot(self):
  data=json.loads((ROOT/'docs/registry-tokens-fase19.json').read_text())
  self.assertEqual(len(data['styles']),11)
  styles={x['id']:x['fields'] for x in data['styles']}
  self.assertEqual(styles['s0']['bg'],'32,ebffb9')
  self.assertEqual(styles['s11']['bg'],'64,ebffb9,0,a0b419,200,a0b419')
  self.assertEqual(styles['s12']['fr'],'1,1,1,7d147d')
  self.assertEqual(styles['s7']['cfr'],'5,0,1,a0b419')
  self.assertFalse('bg' in styles['s7'])
  self.assertTrue(all(set(x['fields']) <= {'bg','cbg','xc','lf','tf','tc','lc','cfr','fr'} for x in data['styles']))
 def test_generated_lua_has_all_tokens(self):
  data=json.loads((ROOT/'docs/registry-tokens-fase19.json').read_text())
  lua=(ROOT/'client/lib/registry_tokens.lua').read_text()
  for style in data['styles']:
   self.assertIn('id="'+style['id']+'"',lua)
   for k,v in style['fields'].items():
    self.assertIn('["'+k+'"]="'+v+'"',lua)
  self.assertIn('mode ~= "32"',lua)
 def test_against_supplied_jar_when_available(self):
  import os, hashlib
  original=os.environ.get('QEEP_ORIGINAL_JAR')
  if not original: self.skipTest('JAR not included in public repository')
  jar=Path(original)
  data=json.loads((ROOT/'docs/registry-tokens-fase19.json').read_text())
  self.assertEqual(hashlib.sha256(jar.read_bytes()).hexdigest(),data['source_sha256'])
  raw=zipfile.ZipFile(jar).read('registry.ini').decode('latin1')
  entries={}
  for line in raw.splitlines():
   m=re.match(r'^(s\d+)=(.*)$',line)
   if m: entries[m.group(1)]={v.split(':',1)[0]:v.split(':',1)[1] for v in m.group(2).split(';') if v}
  self.assertEqual(entries,{x['id']:x['fields'] for x in data['styles']})

if __name__=='__main__':unittest.main()
