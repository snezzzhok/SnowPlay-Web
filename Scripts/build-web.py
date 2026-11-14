#!/usr/bin/env python3
"""Export only the public browser scene; no native settings, logs or reference videos."""
import argparse,json,shutil,hashlib,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--out',default='.build/public-web');args=parser.parse_args()
out=Path(args.out).resolve();source=ROOT/'Web';art=ROOT/'Sources/SnowPlay/Resources/SnowPlayAssets'
if out in [ROOT,source,art] or ROOT not in out.parents: raise SystemExit('Output must be a separate directory inside this checkout')
out.mkdir(parents=True,exist_ok=True)
for item in source.iterdir():
    if item.is_file() and item.suffix in ['.html','.css','.js']: shutil.copyfile(item,out/item.name)
ids=set('snowflake_icon tree_trunk tree_bare tree_balls_gold tree_string_multi tree_topper_gold snowman_complete snowball_small snowball_medium snowball_large santa_sleigh santa_character sleigh gift_sack magic_trail gift_closed gift_open gift_parachute snowplow_complete snowplow_body snowplow_blade snowplow_wheels snowplow_beacon'.split())
entries={}
for manifest in [art/'manifest.json',art/'World/manifest.json']:
    for a in json.loads(manifest.read_text())['assets']:
        if a['id'] not in ids:continue
        path=art/a['svg'];target=out/'assets'/a['svg'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
        entries[a['id']]={'id':a['id'],'svg':a['svg'],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
assert ids==set(entries),f'Missing: {ids-set(entries)}'
(out/'assets/manifest.json').write_text(json.dumps({'project':'SnowPlay Web','source':'Original SnowPlay vector library; World derivatives from this project','assets':list(entries.values())},indent=2)+'\n')
# Content keys prevent a freshly deployed page from importing old cached modules.
digest=hashlib.sha256()
for path in sorted(source.iterdir()):
    if path.suffix in ['.html','.css','.js']:digest.update(path.read_bytes())
for key in sorted(entries):digest.update(entries[key]['sha256'].encode())
version=digest.hexdigest()[:12]
for path in out.glob('*.js'):
    text=path.read_text()
    text=re.sub(r"(from\s+['\"])(\./[^'\"?]+\.js)(['\"])",lambda m:m[1]+m[2]+'?v='+version+m[3],text)
    path.write_text(text)
html=(out/'index.html').read_text().replace('./app.js"','./app.js?v='+version+'"').replace('./style.css"','./style.css?v='+version+'"')
for asset in entries.values():html=html.replace('./assets/'+asset['svg']+'"','./assets/'+asset['svg']+'?v='+asset['sha256'][:12]+'"')
(out/'index.html').write_text(html)
(out/'.nojekyll').touch()
print(f'Built {out.relative_to(ROOT)}: {len(entries)} original SVG assets, relative paths, cache key {version}, no dependencies')
