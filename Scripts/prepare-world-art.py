#!/usr/bin/env python3
"""Original project-native vector character parts and lossless toy extraction.
No pixels or vector art from competitors are used. Original 63-entry manifest is untouched.
"""
import json,copy,xml.etree.ElementTree as ET
from pathlib import Path
base=Path(__file__).resolve().parents[1]/'Sources/SnowPlay/Resources/SnowPlayAssets';out=base/'World';out.mkdir(exist_ok=True)
defs='<defs><linearGradient id="fur" x2=".8" y2="1"><stop stop-color="#fff"/><stop offset=".6" stop-color="#ECF7FE"/><stop offset="1" stop-color="#B8D9EC"/></linearGradient><linearGradient id="ice" x2=".8" y2="1"><stop stop-color="#BCECF1"/><stop offset="1" stop-color="#73BBCF"/></linearGradient><linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#FFE8A6"/><stop offset="1" stop-color="#DFA65C"/></linearGradient></defs>'
# Registered on a 128-square rig canvas; feet, shoulders and face are independently animated.
parts={
'yeti_body':'<path d="M39 58 Q27 70 28 92 L24 96 32 98 Q33 110 43 114 L49 110 Q64 118 79 110 L85 114 Q98 108 97 96 L103 92 98 88 Q100 70 88 59 Z" fill="url(#fur)" stroke="#9DC5D9" stroke-width="2"/><ellipse cx="63" cy="88" rx="21" ry="22" fill="#D3EDF5" opacity=".65"/><path d="M44 71q5 6 9 0m8 1q4 7 8 0m7 0q5 5 9-1" fill="none" stroke="#F9FDFF" stroke-width="3" stroke-linecap="round"/>',
'yeti_head':'<path d="M33 40 Q26 28 35 20 L44 24 Q56 10 73 22 L84 18 Q99 26 94 42 L99 47 93 51 Q94 69 78 76 L72 71 Q61 80 51 72 L42 76 Q28 69 31 54 L25 49 Z" fill="url(#fur)" stroke="#9DC5D9" stroke-width="2"/><path d="M41 25Q35 11 45 12L50 22M77 23Q84 9 90 16L86 29" fill="url(#gold)" stroke="#D8AC69" stroke-width="1.4"/><ellipse cx="63" cy="49" rx="25" ry="22" fill="url(#ice)"/><ellipse cx="54" cy="47" rx="6" ry="8" fill="#244653"/><ellipse cx="75" cy="47" rx="6" ry="8" fill="#244653"/><circle cx="56" cy="44" r="2.4" fill="white"/><circle cx="77" cy="44" r="2.4" fill="white"/><ellipse cx="44" cy="57" rx="6" ry="3.5" fill="#F6AFB7" opacity=".85"/><ellipse cx="84" cy="57" rx="6" ry="3.5" fill="#F6AFB7" opacity=".85"/><path d="M56 59q8 9 16 0" fill="#244653" stroke="#244653" stroke-linejoin="round" stroke-width="2"/><path d="M60 60v4l3-4m5 0v4l3-5" fill="white"/>',
'yeti_arm_left':'<path d="M34 65Q23 61 18 75L13 91Q12 100 20 101Q27 101 28 91L37 75Z" fill="url(#fur)" stroke="#9DC5D9" stroke-width="2"/><path d="m14 92 4-1m-3 5 5-2" stroke="#8FB8D0" stroke-linecap="round"/>',
'yeti_arm_right':'<path d="M92 65Q103 61 108 75L114 91Q115 100 106 101Q99 101 98 91L89 75Z" fill="url(#fur)" stroke="#9DC5D9" stroke-width="2"/><path d="m111 92-4-1m3 5-5-2" stroke="#8FB8D0" stroke-linecap="round"/>',
'yeti_foot_left':'<path d="M39 103Q31 109 32 118Q45 124 55 117L54 105Z" fill="url(#fur)" stroke="#9DC5D9" stroke-width="2"/><path d="m36 117 1-4m6 7v-5m6 4v-4" stroke="#80AFC5" stroke-linecap="round"/>',
'yeti_foot_right':'<path d="M73 105 72 117Q84 124 97 118Q98 109 88 103Z" fill="url(#fur)" stroke="#9DC5D9" stroke-width="2"/><path d="m77 117 1-4m6 7v-5m7 3-1-4" stroke="#80AFC5" stroke-linecap="round"/>',
'yeti_axe':'<path d="M63 57 63 103" stroke="#8D694F" stroke-width="8" stroke-linecap="round"/><path d="M63 57 63 101" stroke="#C49A70" stroke-width="4" stroke-linecap="round"/><path d="M58 43Q42 40 34 51Q43 57 49 68Q58 64 67 57L72 55 74 45Z" fill="#B4D0DB" stroke="#6F929F" stroke-width="2"/><path d="M35 51Q43 57 49 68" fill="none" stroke="#E6F7FB" stroke-width="3"/>'}
entries=[]
for ident,art in parts.items():
 (out/(ident+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">{defs}{art}</svg>')
 entries.append({'id':ident,'category':'Characters','svg':'World/'+ident+'.svg','preview':'Prepared/'+ident+'@2x.png','anchor':{'x':.5,'y':.5},'size':{'width':128,'height':128},'authorship':'Original SnowPlay vector art for the Interactive Winter World brief'})
ns='{http://www.w3.org/2000/svg}';original=ET.parse(base/'Christmas/tree_ornaments.svg').getroot();circles=[e for e in original if e.tag==ns+'circle']
for i in range(7):
 svg=copy.deepcopy(original)
 for child in list(svg):
  if child.tag!=ns+'defs':svg.remove(child)
 for child in circles[i*2:i*2+2]:svg.append(copy.deepcopy(child))
 # Preserve the supplied vector geometry, crop its own viewbox around one ornament.
 c=circles[i*2];cx=float(c.get('cx'));cy=float(c.get('cy'));svg.set('viewBox',f'{cx-11} {cy-12} 22 24');svg.set('width','22');svg.set('height','24')
 ident=f'tree_toy_{i}';ET.ElementTree(svg).write(out/(ident+'.svg'),encoding='unicode')
 entries.append({'id':ident,'category':'Christmas','svg':'World/'+ident+'.svg','preview':'Prepared/'+ident+'@2x.png','anchor':{'x':.5,'y':.16},'size':{'width':22,'height':24},'authorship':'Derived losslessly from Christmas/tree_ornaments.svg, circles '+str(i*2)+'/'+str(i*2+1)})
known={e['id'] for e in entries}
existing=json.loads((out/'manifest.json').read_text())['assets'] if (out/'manifest.json').exists() else []
entries.extend(e for e in existing if e['id'] not in known)
(out/'manifest.json').write_text(json.dumps({'assets':entries},indent=2)+'\n')
