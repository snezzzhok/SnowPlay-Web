#!/usr/bin/env python3
"""Original component vectors in SnowPlay's palette; no reference image crops."""
from pathlib import Path
import json,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[1]
folder=ROOT/'Sources/SnowPlay/Resources/SnowPlayAssets/World'
manifest=json.loads((folder/'manifest.json').read_text());rows={a['id']:a for a in manifest['assets']}
defs='''<defs><linearGradient id="snow" x2=".7" y2="1"><stop stop-color="#fff"/><stop offset="1" stop-color="#c0d9ee"/></linearGradient><linearGradient id="red" x2=".7" y2="1"><stop stop-color="#ff8b7c"/><stop offset="1" stop-color="#cc3c57"/></linearGradient><linearGradient id="green" x2=".7" y2="1"><stop stop-color="#93d8b1"/><stop offset="1" stop-color="#2c8e76"/></linearGradient><linearGradient id="gold" x2=".6" y2="1"><stop stop-color="#ffe8a0"/><stop offset="1" stop-color="#eeb656"/></linearGradient></defs>'''
def add(ident,art,w=128,h=128,anchor=(.5,.5)):
    (folder/(ident+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{art}</svg>')
    rows[ident]={'id':ident,'category':'Characters','svg':'World/'+ident+'.svg','preview':'Prepared/'+ident+'@2x.png','size':{'width':w,'height':h},'anchor':{'x':anchor[0],'y':anchor[1]},'authorship':'Original SnowPlay Living Winter vector components'}
for color,fill in [('red','url(#red)'),('green','url(#green)'),('blue','#6d9ec1')]:
    add('gnome_body_'+color,f'<path d="M43 66Q31 82 34 105Q64 118 94 105Q98 83 84 66Z" fill="{fill}" stroke="#45596c" stroke-width="2"/><path d="M36 99Q64 107 92 99" fill="none" stroke="#f1d1a1" stroke-width="4"/><rect x="57" y="96" width="15" height="8" rx="2" fill="url(#gold)"/><circle cx="64" cy="83" r="2" fill="#ffe4ad"/>')
add('gnome_head','<ellipse cx="64" cy="55" rx="25" ry="24" fill="#efc2a1" stroke="#b88c80" stroke-width="1.5"/><path d="M39 56Q43 100 64 103Q89 91 89 56Q64 75 39 56" fill="url(#snow)" stroke="#adcadf" stroke-width="1.5"/><path d="M50 75Q58 87 64 94M78 76Q73 88 68 94" fill="none" stroke="#bfd4e5" stroke-width="2"/><ellipse cx="64" cy="60" rx="12" ry="10" fill="#f4c9aa" stroke="#d0a18b" stroke-width="1.5"/><circle cx="51" cy="51" r="2.5" fill="#39465b"/><circle cx="77" cy="51" r="2.5" fill="#39465b"/><path d="M47 44L55 43M73 43L81 45" stroke="#fff" stroke-width="4" stroke-linecap="round"/>')
add('gnome_hat','<path d="M36 49Q48 24 73 8Q68 29 92 49Z" fill="url(#red)" stroke="#c44a5f" stroke-width="2"/><path d="M35 49Q64 43 93 49" stroke="#f8f4e8" stroke-width="9" stroke-linecap="round"/><circle cx="73" cy="9" r="5" fill="#fff3dc"/><path d="M60 26L68 23" stroke="#ffc7aa" stroke-width="2" stroke-linecap="round"/>')
for side,x in [('left',46),('right',82)]:
    add('gnome_foot_'+side,f'<path d="M{x-9} 104Q{x-13} 115 {x-9} 120H{x+8}Q{x+13} 116 {x+6} 108Z" fill="#5b5365" stroke="#3c485c" stroke-width="2"/><path d="M{x-7} 116H{x+6}" stroke="#b9cbd5" stroke-width="2"/>')
    ax=34 if side=='left' else 94
    arm=f'<path d="M{ax} 71Q{ax-4 if side=="left" else ax+4} 79 {ax} 88" fill="none" stroke="#375e60" stroke-width="12" stroke-linecap="round"/>'
    if side=='left':arm+=f'<ellipse cx="{ax}" cy="89" rx="7" ry="8" fill="#eed8bd" stroke="#c5a891" stroke-width="1.5"/>'
    add('gnome_arm_'+side,arm)
add('gnome_palm','<ellipse cx="9" cy="9" rx="7" ry="7" fill="#eed8bd" stroke="#c5a891" stroke-width="1.3"/><path d="M4 8Q2 5 5 4" fill="none" stroke="#c5a891" stroke-width="1.3"/>',18,18)
add('yeti_palm','<path d="M3 13Q0 3 6 4Q11-2 15 5Q20 6 15 16Q7 21 3 13" fill="url(#snow)" stroke="#aac8df" stroke-width="1.3"/>',20,20)
for name,mouth,brows in [('happy','M52 56Q64 68 76 56','M50 40Q55 36 60 40M69 40Q74 36 79 40'),('surprised','M60 58Q64 51 68 58Q67 67 62 64Z','M50 36L59 35M70 35L79 36'),('tired','M56 61Q64 55 72 61','M50 42L59 44M70 44L79 42'),('angry','M56 62Q64 57 72 62','M50 37L60 42M69 42L79 37')]:
    add('yeti_emotion_'+name,f'<ellipse cx="64" cy="61" rx="14" ry="9" fill="#c5eaf4"/><path d="{brows}" fill="none" stroke="#536786" stroke-width="2.8" stroke-linecap="round"/><path d="{mouth}" fill="none" stroke="#536786" stroke-width="2.4" stroke-linecap="round"/>')
# Truck components share one 320×180 canvas. Wheel centres and cargo grip are stable.
add('truck_body','<path d="M45 109V65Q45 43 68 43H108Q125 43 131 66L143 92V121H48Z" fill="url(#red)" stroke="#a84e61" stroke-width="3"/><path d="M64 57H104Q112 57 120 82H64Z" fill="#b8dce6" stroke="#7195ac" stroke-width="2"/><path d="M88 57V82" stroke="#dc7e79" stroke-width="3"/><path d="M49 101H138V125H49Z" fill="url(#green)"/><rect x="43" y="113" width="22" height="13" rx="5" fill="#ffe5a1"/><path d="M124 91H139V114H124Z" fill="#d55f65"/><path d="M72 94H88" stroke="#ffe0b4" stroke-width="3" stroke-linecap="round"/>',320,180)
add('truck_platform','<rect x="141" y="103" width="136" height="18" rx="6" fill="url(#green)" stroke="#467d76" stroke-width="3"/><rect x="144" y="94" width="130" height="10" rx="3" fill="#be9b78"/><path d="M151 98H267" stroke="#f4d3a8" stroke-width="2"/><rect x="265" y="83" width="9" height="26" rx="3" fill="#668f78"/>',320,180)
for side,x in [('front',83),('rear',237)]:
    add('truck_wheel_'+side,f'<circle cx="{x}" cy="125" r="22" fill="#41526a" stroke="#31445b" stroke-width="3"/><circle cx="{x}" cy="125" r="14" fill="url(#gold)" stroke="#dca45b" stroke-width="2"/><path d="M{x-8} 125H{x+8}M{x} 117V133" stroke="#fff0bd" stroke-width="3"/><circle cx="{x}" cy="125" r="5" fill="#758996"/>',320,180)
add('truck_lights','<ellipse cx="41" cy="119" rx="11" ry="8" fill="#fff1bf" opacity=".4"/><rect x="40" y="115" width="13" height="8" rx="3" fill="#fff4c4"/><rect x="269" y="112" width="7" height="9" rx="2" fill="#f09787"/>',320,180)
add('truck_ribbon','<path d="M129 75Q116 91 105 73Q123 67 129 75Q146 62 151 76Q140 88 129 75" fill="#f0d68a" stroke="#c6a86b" stroke-width="1.5"/><path d="M128 76L125 94M130 76L140 93" stroke="#edc476" stroke-width="5"/>',320,180)
for i,art in enumerate(['<path d="M8 20Q0 6 15 5Q25-1 31 7Q46 5 43 21Q39 33 27 31Q12 37 8 20Z"/>','<path d="M5 18Q3 5 14 8Q23-3 32 8Q45 8 40 24Q27 38 18 29Q5 30 5 18Z"/>']):
    add('snow_clump_'+str(i),art.replace('/>',' fill="url(#snow)" stroke="#c2d9e8" stroke-width="1.2"/>'),48,36)
ns='{http://www.w3.org/2000/svg}';ET.register_namespace('',ns[1:-1])
head=ET.parse(folder/'yeti_head.svg').getroot()
for child in list(head):
    if child.get('id','').startswith('living-ear') or child.get('d','').startswith('M41 25Q35 11'):head.remove(child)
for side,x in [('left',31),('right',97)]:
    ear=ET.Element(ns+'g',{'id':'living-ear-'+side})
    ET.SubElement(ear,ns+'ellipse',{'cx':str(x),'cy':'35','rx':'8','ry':'11','fill':'#e8f8ff','stroke':'#a6cbdc','stroke-width':'1.5'})
    ET.SubElement(ear,ns+'ellipse',{'cx':str(x),'cy':'35','rx':'4','ry':'6','fill':'#e8c1ce'})
    head.insert(1,ear)
ET.ElementTree(head).write(folder/'yeti_head.svg',encoding='unicode')
face=ET.parse(folder.parent/'Snowman/snowman_face.svg').getroot()
for element in list(face):
    if element.tag==ns+'circle' and element.get('cy')=='51':
        x=float(element.get('cx'));element.tag=ns+'path';element.attrib={'d':f'M{x-4} 51Q{x} 54 {x+4} 51','fill':'none','stroke':'#2D3244','stroke-width':'2.5','stroke-linecap':'round'}
ET.ElementTree(face).write(folder/'snowman_face_closed.svg',encoding='unicode')
rows['snowman_face_closed']={'id':'snowman_face_closed','category':'Snowman','svg':'World/snowman_face_closed.svg','preview':'Prepared/snowman_face_closed@2x.png','size':{'width':256,'height':256},'anchor':{'x':.5,'y':.5},'authorship':'Blink variant derived from supplied standalone snowman_face vector'}
# The original trunk also contains a ground shadow. A carried tree must not rotate that shadow.
stem=ET.parse(folder.parent/'Christmas/tree_trunk.svg').getroot()
for element in list(stem):
    if element.tag==ns+'ellipse':stem.remove(element)
ET.ElementTree(stem).write(folder/'tree_stem.svg',encoding='unicode')
rows['tree_stem']={'id':'tree_stem','category':'Christmas','svg':'World/tree_stem.svg','preview':'Prepared/tree_stem@2x.png','size':{'width':256,'height':256},'anchor':{'x':.5,'y':.5},'authorship':'Standalone trunk extracted from supplied vector; original source retained'}
manifest['assets']=list(rows.values());(folder/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Living Winter component registry:',len(rows))
