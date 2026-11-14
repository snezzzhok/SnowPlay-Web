#!/usr/bin/env python3
"""Generate original layered SVG + transparent 1x/2x PNG from the same primitives.
Requires Pillow only for export. No external art, fonts or network resources.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import json, math, shutil
root=Path(__file__).resolve().parents[1]
svg_dir=root/'LegacyAssets/SVG'; png_dir=root/'LegacyAssets/PNG'
svg_dir.mkdir(parents=True,exist_ok=True); png_dir.mkdir(parents=True,exist_ok=True)
# All animation layers share a 96×96 logical canvas. No embedded background.
assets={}
def ellipse(box,color): return ('ellipse',box,color)
def rect(box,color): return ('rect',box,color)
def poly(points,color): return ('polygon',points,color)
def add(name,*shapes): assets[name]=list(shapes)
white='#f1f7fa'; red='#ca6971'; green='#66978a'; gold='#e4c47f'; dark='#414d59'
add('tree_body',poly([(48,8),(28,36),(35,36),(19,57),(29,57),(12,80),(84,80),(67,57),(77,57),(61,36),(68,36)],green))
add('tree_trunk',rect((43,76,53,91),'#ae8871'))
add('tree_star',poly([(48,2),(51,8),(58,9),(53,14),(54,21),(48,17),(42,21),(43,14),(38,9),(45,8)],gold))
add('ornaments',*[ellipse((x-2,y-2,x+2,y+2),c) for x,y,c in [(40,30,red),(55,47,gold),(34,57,'#c9dfea'),(58,69,red),(28,72,gold)]])
add('tree_lights',*[ellipse((x-1,y-1,x+1,y+1),gold) for x,y in [(45,24),(51,38),(38,45),(61,57),(45,66),(23,76),(72,76)]])
add('tree_snow',poly([(29,36),(47,12),(40,32),(52,36)],white),poly([(21,57),(34,41),(29,54),(43,58)],white),poly([(14,80),(28,64),(24,76),(40,80)],white))
add('tree_shadow',ellipse((22,88,76,94),'#cad4dc40'))
add('snowball_small',ellipse((40,40,56,56),white))
add('snowball_medium',ellipse((34,34,62,62),white))
add('snowball_large',ellipse((31,31,65,65),white))
add('snowman_base',ellipse((28,56,68,94),white))
add('snowman_middle',ellipse((33,35,63,67),white))
add('snowman_head',ellipse((37,17,59,41),white))
add('snowman_details',ellipse((42,25,44,27),dark),ellipse((52,25,54,27),dark),poly([(48,29),(59,32),(48,33)],'#dba174'),rect((36,39,62,43),red),rect((54,42,59,57),red),ellipse((47,49,49,51),dark),ellipse((47,57,49,59),dark))
add('plow_body',rect((16,54,69,73),red),rect((42,33,65,60),red),rect((46,37,61,51),'#c9e2e8'),poly([(70,55),(85,50),(87,77),(70,73)],'#b3c6d3'))
add('plow_wheels',ellipse((21,66,36,81),dark),ellipse((52,66,67,81),dark),ellipse((26,71,31,76),'#d6e2e8'),ellipse((57,71,62,76),'#d6e2e8'))
add('sleigh_body',poly([(13,51),(71,51),(77,45),(80,47),(76,64),(25,67)],red),rect((18,71,78,74),gold),rect((31,63,34,74),gold),rect((64,62,67,74),gold))
add('santa_body',ellipse((24,30,53,59),red),ellipse((28,19,49,40),'#e4bda8'),ellipse((27,29,50,43),white),poly([(28,22),(45,11),(51,24)],red),ellipse((46,20,53,27),white))
add('santa_bag',ellipse((53,30,76,58),'#b29173'))
add('gift_box',rect((28,50,68,87),'#b88390'),rect((45,50,51,87),gold))
add('gift_lid',rect((24,45,72,54),red),rect((45,45,51,54),gold),ellipse((35,38,48,46),gold),ellipse((48,38,61,46),gold))
add('parachute',poly([(16,30),(22,14),(35,5),(48,2),(61,5),(74,14),(80,30),(64,25),(48,31),(32,25)],'#c9dfe7'),poly([(18,30),(29,50),(31,50),(20,30)],'#b3c9d4'),poly([(76,30),(65,50),(67,50),(78,30)],'#b3c9d4'))
for name,c in [('mochi',white),('puffy','#c6b6d8'),('bubi','#b5d8cb')]:
 for state in ['idle','walk','sleep','reaction']:
  for frame in range(4):
   bob=[0,1,0,-1][frame] if state!='sleep' else 0
   dy=-4 if state=='reaction' and frame in (1,2) else bob
   shapes=[ellipse((17,21+dy,79,80+dy),c),ellipse((14,59+dy,30,75+dy),c),ellipse((66,59+dy,82,75+dy),c),ellipse((27+(2 if frame%2 else 0),73+dy,43,86+dy),c),ellipse((53,73+dy,69-(2 if frame%2 else 0),86+dy),c)]
   if state=='sleep': shapes += [rect((32,48,39,50),dark),rect((57,48,64,50),dark)]
   else: shapes += [ellipse((33,43+dy,37,47+dy),dark),ellipse((59,43+dy,63,47+dy),dark)]
   shapes += [ellipse((45,53+dy,51,56+dy),'#c89097')]
   add(f'{name}_{state}_{frame}',*shapes)
for index in range(4):
 shapes=[]
 for j in range(5):
  x=12+j*8; y=20+j*10
  shapes += [poly([(x,y),(x+1,y),(x+8,y-7),(x+8,y-5)],'#d6eaf2'),poly([(x,y),(x+1,y),(x-6,y-6),(x-6,y-4)],'#d6eaf2')]
 add(f'frost_{index}',*shapes)
for index in range(6): add(f'snow_dot_{index}',ellipse((46,46,49+(index%2),49+(index%2)),white))
for index in range(4): add(f'snow_cap_{index}',poly([(6,70),(14,66-index),(27,65),(42,67),(55,64+index),(70,66),(90,65),(90,72),(6,72)],white))
add('garland_bulb',ellipse((44,44,48,49),gold))
manifest={}
for name,shapes in assets.items():
 lines=['<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">']
 for kind,coords,color in shapes:
  color_svg=color[:7]; opacity=int(color[7:9],16)/255 if len(color)==9 else 1
  fill=f'fill="{color_svg}" fill-opacity="{opacity:.3f}"'
  if kind=='ellipse':
   x1,y1,x2,y2=coords; lines.append(f'<ellipse cx="{(x1+x2)/2}" cy="{(y1+y2)/2}" rx="{(x2-x1)/2}" ry="{(y2-y1)/2}" {fill}/>')
  elif kind=='rect':
   x1,y1,x2,y2=coords; lines.append(f'<rect x="{x1}" y="{y1}" width="{x2-x1}" height="{y2-y1}" {fill}/>')
  else: lines.append(f'<polygon points="'+ ' '.join(f'{x},{y}' for x,y in coords)+f'" {fill}/>')
 lines.append('</svg>'); (svg_dir/f'{name}.svg').write_text('\n'.join(lines)+'\n')
 for scale in (1,2):
  aa=scale*3; image=Image.new('RGBA',(96*aa,96*aa)); draw=ImageDraw.Draw(image)
  for kind,coords,color in shapes:
   rgba=tuple(bytes.fromhex(color[1:7]))+((int(color[7:9],16) if len(color)==9 else 255),)
   if kind=='polygon': draw.polygon([(x*aa,y*aa) for x,y in coords],fill=rgba)
   else: getattr(draw,"rectangle" if kind=="rect" else kind)(tuple(v*aa for v in coords),fill=rgba)
  image=image.resize((96*scale,96*scale),Image.Resampling.LANCZOS)
  suffix='' if scale==1 else '@2x'; image.save(png_dir/f'{name}{suffix}.png',optimize=True)
 manifest[name]={'canvas':[96,96],'svg':f'SVG/{name}.svg','png':f'PNG/{name}.png','retina':f'PNG/{name}@2x.png'}
# Compact sprite strips, retained in source exports; runtime lazily uses individual frames.
for name in ['mochi','puffy','bubi']:
 sheet=Image.new('RGBA',(384,384))
 for row,state in enumerate(['idle','walk','sleep','reaction']):
  for i in range(4): sheet.alpha_composite(Image.open(png_dir/f'{name}_{state}_{i}.png'),(i*96,row*96))
 sheet.save(png_dir/f'{name}_sprites.png',optimize=True)
(root/'LegacyAssets/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
target=root/'Sources/SnowPlay/Resources/Art'; target.mkdir(exist_ok=True)
for f in png_dir.glob('*.png'):
 if 'sprites' not in f.name: shutil.copy2(f,target/f.name)
print(f'{len(assets)} vector layers, transparent PNG 1x/2x; {sum(p.stat().st_size for p in (root/"Assets").rglob("*.*")):,} bytes total')
# Contact sheet for inspecting exported artwork; not an application screenshot.
items=[('Tree',['tree_shadow','tree_trunk','tree_body','ornaments','tree_lights','tree_snow','tree_star']),('Snowman',['snowman_base','snowman_middle','snowman_head','snowman_details']),('Plow',['plow_body','plow_wheels']),('Santa',['sleigh_body','santa_bag','santa_body']),('Gift',['gift_box','gift_lid','parachute']),('Mochi',['mochi_idle_0']),('Puffy',['puffy_idle_0']),('Bubi',['bubi_idle_0'])]
preview=Image.new('RGBA',(8*112,138),'#edf2ed');draw=ImageDraw.Draw(preview)
for i,(label,names) in enumerate(items):
 for name in names: preview.alpha_composite(Image.open(png_dir/f'{name}.png'),(i*112+8,8))
 draw.text((i*112+24,116),label,fill='#4c625a')
preview.save(root/'LegacyAssets/preview.png',optimize=True)
