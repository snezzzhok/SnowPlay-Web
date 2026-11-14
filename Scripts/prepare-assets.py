#!/usr/bin/env python3
"""Validate supplied registry, isolate original SVG primitives, rasterize once offline."""
import json, hashlib, subprocess, xml.etree.ElementTree as ET, sys, shutil, struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]; assets=root/'Sources/SnowPlay/Resources/SnowPlayAssets'
m=json.loads((assets/'manifest.json').read_text()); extra=json.loads((assets/'World/manifest.json').read_text()) if (assets/'World/manifest.json').exists() else {'assets':[]}; all_assets=m['assets']+extra['assets']; out=assets/'Prepared'; out.mkdir(exist_ok=True)
if '--check' in sys.argv:
    index=json.loads((out/'index.json').read_text())
    assert len(m['assets'])==63 and len({a['id'] for a in m['assets']})==63
    for a in all_assets:
        for key in ['svg','preview']:
            path=Path(a[key]); assert not path.is_absolute() and '..' not in path.parts and (assets/path).is_file()
    for e in index['assets']:
        assert hashlib.sha256((assets/e['source']).read_bytes()).hexdigest()==e['sha256'],e['id']
        for scale in [1,2]:
            data=(out/(e['id']+('@2x' if scale==2 else '')+'.png')).read_bytes()
            assert data[:8]==b'\x89PNG\r\n\x1a\n'
            w,h=struct.unpack('>II',data[16:24]); import math
            assert (w,h)==(math.ceil(e['width']*scale),math.ceil(e['height']*scale)),e['id']
    atlas=json.loads((out/'Atlas/index.json').read_text())
    from PIL import Image,ImageChops
    for a in atlas['assets']:
        sheet=Image.open(out/f'Atlas/characters-{a["page"]}.png').convert('RGBA')
        crop=sheet.crop((a['x'],a['y'],a['x']+a['width'],a['y']+a['height']))
        assert ImageChops.difference(crop,Image.open(out/(a['id']+'@2x.png')).convert('RGBA')).getbbox() is None,a['id']
    print(f'PASS: 63 originals; {len(extra["assets"])} project art entries; {len(index["assets"])} prepared sources with Retina PNGs')
    sys.exit(0)
ns='{http://www.w3.org/2000/svg}'; ET.register_namespace('',ns[1:-1])
entries={}
for a in all_assets:
    for key in ['svg','preview']:
        p=Path(a[key]); assert not p.is_absolute() and '..' not in p.parts and ((assets/p).is_file() or a in extra['assets'] and key=='preview'),p
    assert a['id'] not in entries
    entries[a['id']]={**a,'source':a['svg']}
# Preserve original coordinates/defs; separate actual vector primitives, never redraw or crop catalogues.
for ident,source,select in [
 ('snowman_ball_base','snowman_body',lambda e:e.tag==ns+'circle' and e.get('cy')=='175'),
 ('snowman_ball_middle','snowman_body',lambda e:e.tag==ns+'circle' and e.get('cy')=='113'),
 ('snowman_ball_head','snowman_body',lambda e:e.tag==ns+'circle' and e.get('cy')=='55'),
 ('snowplow_wheel_left','snowplow_wheels',lambda e:e.tag==ns+'circle' and e.get('cx')=='105'),
 ('snowplow_wheel_right','snowplow_wheels',lambda e:e.tag==ns+'circle' and e.get('cx')=='218')]:
    a=entries[source]; svg=ET.parse(assets/a['svg']).getroot()
    for child in list(svg):
        if child.tag!=ns+'defs' and not select(child): svg.remove(child)
    assert len(list(svg))>1,ident
    path=out/(ident+'.svg'); ET.ElementTree(svg).write(path,encoding='unicode')
    entries[ident]={**a,'id':ident,'source':str(path.relative_to(assets)),'anchor':{'x':.5,'y':.5},'derived_from':source}
rows=[]
for ident,a in entries.items():
    h=220 if ident=='snow_castle' else 10 if a['category']=='Decorations' and ident.startswith('bulb_') else 40 if ident.startswith('frost_') else 56 if a['category']=='Snowman' and not ident.startswith('snowball_') else 80 if a['category'] in ['Santa','Gifts','Effects'] else 64 if a['category']=='Snowplow' else 96
    w=h*a['size']['width']/a['size']['height']
    rows.append({'id':ident,'source':a['source'],'width':w,'height':h,'anchor':a['anchor'],'sha256':hashlib.sha256((assets/a['source']).read_bytes()).hexdigest(),'derived_from':a.get('derived_from')})
(out/'index.json').write_text(json.dumps({'version':1,'assets':rows},indent=2)+'\n')
subprocess.run([(str(root/'.build/toolchain/swiftc') if (root/'.build/toolchain/swiftc').exists() else shutil.which('swiftc')),'-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-target','arm64-apple-macosx13.0',str(root/'Scripts/PrepareTextures.swift'),'-o',str(root/'.build/prepare-textures')],check=True)
subprocess.run([str(root/'.build/prepare-textures'),str(assets)],check=True)
subprocess.run([sys.executable,str(root/'Scripts/pack-character-atlas.py')],check=True)
print(f'Validated {len(m["assets"])} originals; prepared {len(rows)} lazy-loadable textures at 1x/2x.')

subprocess.run([sys.executable,str(root/'Scripts/build-native-catalogue.py')],check=True)
