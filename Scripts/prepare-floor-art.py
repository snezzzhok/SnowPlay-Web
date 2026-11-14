#!/usr/bin/env python3
"""New deterministic vector models for the floor world; supplied originals stay intact."""
import json,math,copy,xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image
base=Path(__file__).resolve().parents[1]/'Sources/SnowPlay/Resources/SnowPlayAssets';out=base/'World'
manifest=json.loads((out/'manifest.json').read_text());rows={e['id']:e for e in manifest['assets']}
def register(i,art,w=256,h=256,anchor=(.5,.5),category='Christmas'):
 (out/(i+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{art}</svg>')
 rows[i]={'id':i,'category':category,'svg':'World/'+i+'.svg','preview':'Prepared/'+i+'@2x.png','size':{'width':w,'height':h},'anchor':{'x':anchor[0],'y':anchor[1]},'authorship':'Original SnowPlay floor-world vector art'}
colors={'red':'#ff777d','green':'#8ce8b0','gold':'#ffd970','blue':'#8abfff','purple':'#ccb0ff'}
for c,color in colors.items():
 art=f'''<defs><radialGradient id="halo"><stop stop-color="{color}" stop-opacity=".25"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient><linearGradient id="glass" x2=".8" y2="1"><stop stop-color="#ffffff"/><stop offset=".3" stop-color="{color}"/><stop offset="1" stop-color="{color}" stop-opacity=".25"/></linearGradient></defs><circle cx="24" cy="29" r="22" fill="url(#halo)"/><path d="M24 0V8" stroke="#365744" stroke-width="2.5"/><rect x="18" y="7" width="12" height="8" rx="2" fill="#486653"/><path d="M18 11H30M18 14H30" stroke="#9eb2a3"/><path d="M18 15Q12 22 16 31Q24 42 32 31Q36 22 30 15Z" fill="url(#glass)" stroke="{color}" stroke-width="1.2"/><path d="M19 20Q16 27 21 30" stroke="#fff" stroke-width="2" fill="none" stroke-linecap="round"/><path d="M21 31L24 24 27 31" stroke="#fff4c9" fill="none"/>'''
 register('fairy_bulb_'+c,art,48,52,(.5,.18),'Decorations')
ns='{http://www.w3.org/2000/svg}'
for c in ['red','green','blue']:
 svg=ET.parse(base/('Decorations/hat_'+c+'.svg')).getroot();children=list(svg);cone=next(e for e in children if e.tag==ns+'path')
 clip=ET.Element(ns+'clipPath',{'id':'knit-clip'});cp=copy.deepcopy(cone);cp.attrib={'d':cone.get('d')};clip.append(cp);svg.find(ns+'defs').append(clip)
 pattern=ET.Element(ns+'g',{'clip-path':'url(#knit-clip)','stroke':'#fff6ee','stroke-width':'3','fill':'none','opacity':'.8'})
 for y in [86,115]:
  ET.SubElement(pattern,ns+'path',{'d':'M45 '+str(y)+' '+ ' '.join(f'L{x} {y+(6 if j%2 else 0)}' for j,x in enumerate(range(45,215,7)))})
 for x,y in [(98,105),(139,99),(166,124)]:
  ET.SubElement(pattern,ns+'path',{'d':f'M{x-6} {y}H{x+6}M{x} {y-6}V{y+6}M{x-4} {y-4}L{x+4} {y+4}M{x-4} {y+4}L{x+4} {y-4}'})
 svg.insert(list(svg).index(cone)+1,pattern);ident='hat_knit_'+c;ET.ElementTree(svg).write(out/(ident+'.svg'),encoding='unicode')
 rows[ident]={'id':ident,'category':'Decorations','svg':'World/'+ident+'.svg','preview':'Prepared/'+ident+'@2x.png','size':{'width':256,'height':220},'anchor':{'x':.5,'y':.78},'authorship':'Patterned derivative of supplied hat_'+c+'.svg; original preserved'}
register('glove_cursor','<path d="M14 37Q4 29 9 25Q13 23 18 29L16 12Q16 5 21 6L25 22 25 6Q27 0 31 5L32 22 36 7Q41 4 42 10L39 26 44 16Q49 13 51 19L47 36Q42 45 32 48L21 47Z" fill="#edfaff" stroke="#81b9d1" stroke-width="2"/><path d="M21 43L38 42 39 53 20 54Z" fill="#ea7275" stroke="#b94e66" stroke-width="2"/><path d="M24 47H34M24 50H34" stroke="#fff" stroke-width="1.5"/>',60,60,(.5,.5),'UI')
# Naked evergreen uses the existing registered silhouette with deeper needles and ridges.
foliage=ET.parse(base/'Christmas/tree_foliage.svg').getroot();extra=ET.Element(ns+'path',{'d':'M107 89Q126 105 147 91M92 142Q125 158 163 143M69 192Q126 219 189 192','fill':'none','stroke':'#268663','stroke-width':'3','opacity':'.5'});foliage.append(extra);ET.ElementTree(foliage).write(out/'tree_bare.svg',encoding='unicode')
rows['tree_bare']={'id':'tree_bare','category':'Christmas','svg':'World/tree_bare.svg','preview':'Prepared/tree_bare@2x.png','size':{'width':256,'height':256},'anchor':{'x':.5,'y':.5},'authorship':'Bare evergreen derivative of supplied tree_foliage.svg'}
for style,color in [('gold','#ffdc70'),('ice','#bceeff'),('ruby','#ff818e')]:
 pts=' '.join(f'{128+math.sin(i*math.pi/5)*(18 if i%2==0 else 8)},{28-math.cos(i*math.pi/5)*(18 if i%2==0 else 8)}' for i in range(10))
 extra='<circle cx="128" cy="28" r="8" fill="#fff7da"/>' if style=='gold' else '<path d="M128 14V42M114 28H142M118 18L138 38M118 38L138 18" stroke="#fff" stroke-width="2"/>' if style=='ice' else '<path d="M128 17L136 28 128 39 120 28Z" fill="#fff0d8"/>'
 register('tree_topper_'+style,f'<defs><radialGradient id="g"><stop stop-color="{color}" stop-opacity=".7"/><stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient></defs><circle cx="128" cy="28" r="28" fill="url(#g)"/><polygon points="{pts}" fill="{color}" stroke="#fff1c7" stroke-width="1.5"/>'+extra)
positions=[(124,74),(111,103),(144,111),(93,132),(126,139),(159,142),(79,167),(110,173),(143,176),(176,178),(66,195),(96,202),(127,199),(158,201),(190,197)]
for style,color in [('red','#fa717c'),('gold','#ffd568'),('ice','#a8dfff')]:
 art=''
 for i,(x,y) in enumerate(positions):
  radius=4.8 if i%3 else 5.8;art+=f'<path d="M{x} {y-radius-4}V{y-radius}" stroke="#ccb77c" stroke-width="1.5"/><circle cx="{x}" cy="{y}" r="{radius}" fill="{color}" stroke="#fff4df" stroke-width=".8"/><circle cx="{x-1.5}" cy="{y-2}" r="1.5" fill="#fff" opacity=".85"/>'
 register('tree_balls_'+style,art)
for style in ['multi','warm','ice']:
 art='<defs>'
 palette=['#ff8095','#94f7b4','#ffe18a','#92cbff'] if style=='multi' else ['#ffe18a','#ffd07b'] if style=='warm' else ['#a7e8ff','#d0c7ff']
 for i,c in enumerate(palette):art+=f'<radialGradient id="l{i}"><stop stop-color="{c}" stop-opacity=".85"/><stop offset="1" stop-color="{c}" stop-opacity="0"/></radialGradient>'
 art+='</defs>'
 for left,right,y in [(105,145,100),(82,171,143),(60,194,185)]:
  art+=f'<path d="M{left} {y}Q128 {y+24} {right} {y}" stroke="#4f7753" stroke-width="1.7" fill="none"/>'
  for j in range(7):
   x=left+(right-left)*j/6;yy=y+12*4*(j/6)*(1-j/6);k=j%len(palette)
   art+=f'<circle cx="{x}" cy="{yy+4}" r="11" fill="url(#l{k})"/><rect x="{x-2.5}" y="{yy-1}" width="5" height="3" rx="1" fill="#446047"/><ellipse cx="{x}" cy="{yy+4}" rx="2.6" ry="4" fill="{palette[k]}"/><circle cx="{x-.7}" cy="{yy+3}" r=".8" fill="#fff"/>'
 register('tree_string_'+style,art)
for i,art in {'bauble':'<circle cx="20" cy="24" r="12" fill="#f77c87" stroke="#ffe3b2" stroke-width="2"/><path d="M9 23Q20 29 31 23" stroke="#ffe4bc" fill="none" stroke-width="2"/><circle cx="16" cy="20" r="3" fill="#fff4e1"/>','candy':'<path d="M17 36V15Q17 5 26 8Q33 11 28 18" stroke="#fff4e7" stroke-width="8" fill="none" stroke-linecap="round"/><path d="M14 30L20 26M14 21L20 17M20 9L24 15M27 9L30 14" stroke="#f17987" stroke-width="3"/>','flake':'<path d="M20 9V36M7 22H33M10 12L30 32M10 32L30 12M16 12L20 16 24 12M10 18L14 22 10 26M16 33L20 29 24 33M30 18L26 22 30 26" fill="none" stroke="#d1f6ff" stroke-width="3" stroke-linecap="round"/>'}.items():
 register('tree_charm_'+i,'<path d="M20 1V9" stroke="#d7bc78" stroke-width="1.5"/>'+art,40,42,(.5,.12))
castle=out/'snow_castle.png'
if castle.exists():
 im=Image.open(castle);bottom=im.getchannel('A').point(lambda a:255 if a>100 else 0).getbbox()[3]/im.height;rows['snow_castle']={'id':'snow_castle','category':'Characters','svg':'World/snow_castle.png','preview':'Prepared/snow_castle@2x.png','size':{'width':im.width,'height':im.height},'anchor':{'x':.5,'y':bottom},'authorship':'Original imagegen transparent raster; prompt/provenance in Docs/Floor-World-Revision.md'}
manifest['assets']=list(rows.values());(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('World registry:',len(rows))
