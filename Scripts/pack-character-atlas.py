#!/usr/bin/env python3
"""Offline shelf packing; registered full canvases and pivots are unchanged."""
from pathlib import Path
from PIL import Image
import json,math
root=Path(__file__).resolve().parents[1]/'Sources/SnowPlay/Resources/SnowPlayAssets/Prepared'
rows=json.loads((root/'index.json').read_text())['assets']
selected=[r for r in rows if r['id'].startswith(('gnome_','truck_','yeti_','snow_clump_','sticker_','story_rig_','story_friend_'))]
folder=root/'Atlas';folder.mkdir(exist_ok=True)
pages=[];items=[];x=y=shelf=0;page=Image.new('RGBA',(1024,1024));pageNo=0
for r in selected:
    image=Image.open(root/(r['id']+'@2x.png')).convert('RGBA');w,h=image.size
    if x+w+2>1024:x=0;y+=shelf+2;shelf=0
    if y+h+2>1024:pages.append(page);pageNo+=1;page=Image.new('RGBA',(1024,1024));x=y=shelf=0
    page.alpha_composite(image,(x+1,y+1));items.append({'id':r['id'],'page':pageNo,'x':x+1,'y':y+1,'width':w,'height':h})
    x+=w+2;shelf=max(shelf,h)
pages.append(page)
for i,p in enumerate(pages):p.save(folder/f'characters-{i}.png',optimize=True)
(folder/'index.json').write_text(json.dumps({'size':1024,'pages':len(pages),'assets':items},indent=2)+'\n')
print(f'Packed {len(items)} components into {len(pages)} shared 1024px texture pages')
