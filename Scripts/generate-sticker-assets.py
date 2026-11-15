#!/usr/bin/env python3
"""Original vector art extending SnowPlay's palette; offline PNG masters and atlas follow."""
from pathlib import Path
import json,math
root=Path(__file__).resolve().parents[1]/'Sources/SnowPlay/Resources/SnowPlayAssets';folder=root/'World';m=json.loads((folder/'manifest.json').read_text())
def path(d,fill='none',stroke=None,width=3):return f'<path d="{d}" fill="{fill}"'+(f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"' if stroke else '')+'/>'
def circle(x,y,r,fill):return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>'
def snowline(d):return path(d,'none','#f5fcff',9)
def bow(x=128,y=90,s=1):return f'<g transform="translate({x} {y}) scale({s})">'+path('M0 0C-72-66-78 41-4 13L-22 68L0 53L24 69L7 12C78 42 73-65 0 0Z','url(#red)','#e5bc63',2)+path('M-7 7Q-35-10-45-5M8 7Q35-13 46-6','none','#ff9b88',3)+circle(0,7,11,'#e45b57')+'</g>'
def pine(x,y,angle=0,s=1):
 body=path('M0 0L0 -85','none','#547753',5)
 for i in range(8):
  yy=-i*10;body+=path(f'M0 {yy}L{-28+i*2} {yy-16}M0 {yy}L{28-i*2} {yy-16}','none','#2f775b' if i%2 else '#438b66',7)
 return f'<g transform="translate({x} {y}) rotate({angle}) scale({s})">{body}</g>'
def cone(x,y,s=1):return f'<g transform="translate({x} {y}) scale({s})"><ellipse rx="13" ry="22" fill="#8b5744"/>'+''.join(path(f'M-10 {i}Q0 {i+9} 10 {i}','none','#bd8d66',3) for i in [-12,-3,6])+'</g>'
def flake(x,y,s=1,color='#e7f8ff'):
 lines=''
 for a in range(0,360,60):lines+=f'<g transform="rotate({a})">'+path('M0 0V-76M0-46L-17-59M0-46L17-59M0-24L-11-34M0-24L11-34','none',color,5)+'</g>'
 return f'<g transform="translate({x} {y}) scale({s})">{lines}</g>'
def star():
 pts=[]
 for i in range(10):a=-math.pi/2+i*math.pi/5;r=108 if i%2==0 else 48;pts.append(f'{128+math.cos(a)*r:.1f},{128+math.sin(a)*r:.1f}')
 return '<polygon points="'+' '.join(pts)+'" fill="url(#gold)" stroke="#ffeec3" stroke-width="5"/>'+path('M128 20L128 130L24 161L99 111Z','#fff4ba')
art={}
body=''
for i in range(22):
 a=i*math.tau/22;body+=pine(128+math.sin(a)*83,120+math.cos(a)*83,-i*360/22,.64)
body+=cone(62,144,.6)+cone(193,135,.7)+''.join(circle(x,y,5,'url(#gold)') for x,y in [(61,70),(91,39),(183,57),(212,107),(192,182),(64,185)])+bow(128,192,.65)
art['wreath']=(256,256,body)
body=snowline('M7 17Q60 4 102 14T208 13T313 15')
for x,h in [(12,52),(40,78),(69,44),(96,87),(127,55),(159,76),(189,39),(221,84),(254,55),(284,77),(309,48)]:body+=path(f'M{x-8} 18L{x} {h+8}L{x+8} 18Z','url(#ice)','#d4f1fa',1)+path(f'M{x-3} 23L{x} {h-8}','none','#fff',1)
art['icicles']=(320,100,body)
body=''
for x,h,w in [(24,152,20),(59,205,22),(91,270,26),(132,187,25),(162,122,14)]:body+=path(f'M{x-w} 16L{x} {h}L{x+w} 16Z','url(#ice)','#c7edf7',2)+path(f'M{x-6} 28L{x} {h-30}','none','#ffffff',3)
art['ice_cluster']=(180,280,body+snowline('M9 16Q87 0 171 16'))
body=path('M21 235L24 24L237 21','none','#d4f3ff',4)
for a in [0,28,48,68,90]:body+=f'<g opacity=".56" transform="translate(24 24) rotate({a})">'+path('M0 0L195 0M45 0L70 23M75 0L101-25M110 0L138 29M145 0L169-20','none','#c4eaff',3)+flake(155,0,.23)+'</g>'
art['frost']=(256,256,'<g opacity=".65">'+body+'</g>')
art['fir_branch']=(320,160,pine(45,115,80,1.8)+pine(150,106,55,1.1)+cone(196,96,.8)+cone(241,85,.5)+snowline('M44 79Q96 50 141 61M174 53Q210 32 250 49'))
body=path('M53 12H143L130 148Q198 138 189 206Q174 254 91 264Q16 265 22 222Q27 194 59 173Z','url(#red)','#873d45',4)+path('M50 9Q96 0 146 9L147 58Q92 69 48 57Z','url(#snow)','#d8e9ec',3)+flake(96,112,.24)+path('M45 209L55 229M71 202L81 222M97 194L107 214','none','#fff4da',4)
art['stocking']=(200,280,body)
art['hat']=(280,220,path('M35 169Q60 65 112 25Q162-12 211 62L244 118L209 127Q170 71 153 91L177 171Z','url(#red)','#973c49',4)+path('M23 165Q130 147 202 166L203 200Q117 219 21 199Z','url(#snow)','#d0e4ec',4)+circle(239,123,25,'url(#snow)')+flake(99,116,.14))
art['scarf']=(260,150,path('M20 20Q132 62 239 20L240 60Q130 103 21 59Z','url(#red)','#973f4a',3)+path('M151 60L215 65L205 139L149 124Z','url(#red)','#973f4a',3)+''.join(path(f'M{x} 122L{x-2} 145','none','#ffe4cf',3) for x in range(153,207,9))+path('M31 41Q128 78 229 41M158 92L207 101','none','#f8ecd3',5)+flake(92,49,.12))
art['bow']=(256,256,bow(128,90,1.32))
art['star']=(256,256,star())
body=pine(120,100,35,.6)+pine(142,100,-40,.6)
for x,a in [(84,17),(176,-17)]:body+=f'<g transform="translate({x} 146) rotate({a})">'+path('M-33 22Q-21 2-23-29Q0-65 23-29Q22 2 36 22Z','url(#gold)','#b98a44',3)+'<ellipse cx="1" cy="22" rx="36" ry="12" fill="#d8a347" stroke="#fff0ba" stroke-width="3"/>'+circle(0,25,10,'#f5c66b')+path('M-13-24Q-19-1-18 8','none','#fff2bf',5)+'</g>'
art['bells']=(256,256,body+bow(128,50,.55))
body=path('M54 251V70C54 1 148 1 148 65V85','none','#fff8e9',36)
for y in range(100,250,43):body+=path(f'M40 {y}L69 {y+18}','none','#d64a51',12)
body+=path('M42 61L75 43M92 20L104 51M135 38L121 65','none','#d64a51',12)
candy='M36 251V68C36-16 166-16 166 65V85H130V65C130 26 72 26 72 68V251Z'
body='<defs><clipPath id="candyClip">'+path(candy,'#fff')+'</clipPath></defs>'+path(candy,'#fff8e9')+'<g clip-path="url(#candyClip)">'+body+'</g>'
art['candy']=(180,280,body+bow(64,132,.4))
body=path('M83 83C32 48 69 4 108 14C161 5 181 57 141 86L189 111Q222 139 194 158L152 145L172 224Q175 263 144 262L110 213L83 260Q48 269 43 237L62 145L26 160Q-4 142 17 118Z','url(#cookie)','#98634b',4)+path('M80 86L107 97L143 87M45 130L27 141M172 130L188 141M73 233L85 214M142 214L153 239','none','#fff5db',6)+circle(90,52,5,'#4d3c3c')+circle(125,52,5,'#4d3c3c')+path('M93 69Q108 80 123 67','none','#fff2d9',4)+circle(110,140,7,'#dd5657')+circle(110,170,7,'#dd5657')+bow(110,107,.3)
art['gingerbread']=(220,280,body)
body=''
for x,y,a in [(93,80,-55),(175,70,50),(145,112,165)]:body+=f'<g transform="translate({x} {y}) rotate({a})">'+path('M0 45Q-48 21-20-6L-25-30L-3-25L0-50L15-28L36-33L29-8Q56 22 0 45Z','url(#green)','#215d4e',3)+path('M0 39V-31','none','#8db77b',2)+'</g>'
body+=circle(128,93,19,'url(#red)')+circle(157,110,18,'url(#red)')+circle(110,120,17,'url(#red)')+snowline('M107 112Q119 102 126 110')
art['holly']=(280,180,body)
body=path('M110 30L103 230M110 75L55 108M108 109L164 146M106 155L57 190','none','#5b8c61',5)
for x,y,a in [(78,91,-50),(62,117,-75),(139,124,45),(162,150,70),(80,167,-50),(56,190,-75),(111,212,0)]:body+=f'<ellipse cx="{x}" cy="{y}" rx="13" ry="29" fill="url(#green)" transform="rotate({a} {x} {y})"/>'
body+=circle(90,132,9,'url(#snow)')+circle(126,176,9,'url(#snow)')+circle(96,215,9,'url(#snow)')+bow(110,34,.58)
art['mistletoe']=(220,280,body)
body=path('M0 17Q160 129 320 17','none','#416552',5)
for x in [18,74,130,186,242,298]:
 y=17+65*(1-((x-160)/160)**2);body+=f'<ellipse cx="{x}" cy="{y+15}" rx="17" ry="24" fill="#ffda83" opacity=".12"/>'+path(f'M{x-4} {y-4}H{x+4}V{y+7}H{x-4}Z','#476455')+f'<ellipse cx="{x}" cy="{y+14}" rx="7" ry="12" fill="url(#gold)"/>'
art['lights']=(320,110,body)
body=path('M82 37Q100-10 120 37','none','#41585a',8)+path('M38 77L62 45H141L165 77L149 234H50Z','url(#metal)','#293d44',4)+path('M56 83H145L132 213H68Z','url(#warm)','#9f835a',3)+path('M100 82V215M58 146H142','none','#41585a',8)+path('M52 235H150V252H52Z','url(#metal)')+path('M90 192H112V139H90Z','#fff2c7')+path('M100 141Q79 122 101 95Q122 122 100 141Z','#fff1ac')+pine(45,244,-55,.55)+bow(136,236,.5)
art['lantern']=(200,280,body)
art['present']=(256,256,'<rect x="33" y="85" width="190" height="143" rx="13" fill="url(#green)" stroke="#1f5f52" stroke-width="4"/><rect x="24" y="67" width="207" height="42" rx="10" fill="#4b9270" stroke="#91b589" stroke-width="3"/>'+path('M111 70H144V229H111Z','url(#red)')+path('M33 148H223V177H33Z','url(#red)')+bow(128,49,.8))
art['sign']=(320,210,path('M142 78H172V200H142Z','#956344','#6d4b3e',4)+'<rect x="14" y="34" width="290" height="112" rx="17" fill="url(#wood)" stroke="#865e48" stroke-width="4"/>'+path('M30 108H283M38 67H276','none','#bd9569',2)+snowline('M15 38Q47 8 88 27Q137 8 166 28Q219 7 251 30Q288 16 304 39')+circle(30,90,4,'#79553f')+circle(289,90,4,'#79553f'))
art['snowflake']=(256,256,flake(128,128,1.3,'#b9e5f8')+flake(128,128,1.05,'#e0f6ff')+circle(128,128,12,'#f4fcff'))
defs='''<defs><linearGradient id="red" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#f27869"/><stop offset=".5" stop-color="#c93f4c"/><stop offset="1" stop-color="#923e4b"/></linearGradient><linearGradient id="green" x2="1" y2="1"><stop stop-color="#67a77c"/><stop offset="1" stop-color="#236750"/></linearGradient><linearGradient id="gold" x2=".8" y2="1"><stop stop-color="#fff2bb"/><stop offset=".5" stop-color="#e5b858"/><stop offset="1" stop-color="#b78841"/></linearGradient><linearGradient id="snow" x2=".6" y2="1"><stop stop-color="#ffffff"/><stop offset="1" stop-color="#d0e5ed"/></linearGradient><linearGradient id="ice" x2="1" y2="0"><stop stop-color="#90cbdc" stop-opacity=".65"/><stop offset=".5" stop-color="#effcff" stop-opacity=".9"/><stop offset="1" stop-color="#bce9f5" stop-opacity=".65"/></linearGradient><linearGradient id="cookie" x2="1" y2="1"><stop stop-color="#dfae6d"/><stop offset="1" stop-color="#ad754d"/></linearGradient><linearGradient id="metal" x2="1" y2="1"><stop stop-color="#74837b"/><stop offset="1" stop-color="#344c51"/></linearGradient><radialGradient id="warm"><stop stop-color="#fff4b6"/><stop offset="1" stop-color="#e3a95e" stop-opacity=".65"/></radialGradient><linearGradient id="wood" x2="0" y2="1"><stop stop-color="#d3af7a"/><stop offset="1" stop-color="#a97850"/></linearGradient></defs>'''
ids={'sticker_'+k for k in art};m['assets']=[a for a in m['assets'] if a['id'] not in ids]
for key,(w,h,body) in art.items():
 id='sticker_'+key;(folder/(id+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{defs}{body}</svg>\n')
 m['assets'].append({'id':id,'category':'Decorations','svg':'World/'+id+'.svg','preview':'Prepared/'+id+'@2x.png','viewBox':[0,0,w,h],'size':{'width':w,'height':h},'anchor':{'x':.5,'y':.5},'components':[],'description':'Original Sticker Studio vector; PNG masters in Stickers; anchor metadata in sticker-metadata.json'})
m['asset_count']=len(m['assets']);(folder/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
print('Created 20 original standalone sticker vectors')
