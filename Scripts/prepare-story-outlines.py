#!/usr/bin/env python3
"""Build compact opaque convex hulls offline, in SpriteKit's lower-left coordinates."""
from pathlib import Path
from PIL import Image
import json
root=Path(__file__).resolve().parents[1]/'Sources/SnowPlay/Resources/SnowPlayAssets/Prepared'
def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
def hull(points):
 points=sorted(set(points))
 if len(points)<3:return points
 lower=[]
 for p in points:
  while len(lower)>=2 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
  lower.append(p)
 upper=[]
 for p in reversed(points):
  while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
  upper.append(p)
 return lower[:-1]+upper[:-1]
result={}
for row in json.loads((root/'index.json').read_text())['assets']:
 im=Image.open(root/(row['id']+'@2x.png')).convert('RGBA');w,h=im.size;alpha=im.getchannel('A');pixels=alpha.load();boundary=[]
 for y in range(h):
  xs=[x for x in range(w) if pixels[x,y]>24]
  if xs:
   l,r=min(xs),max(xs)+1
   boundary.extend([(l,y),(r,y),(l,y+1),(r,y+1)])
 result[row['id']]=[[round(x/w,7),round(1-y/h,7)] for x,y in hull(boundary)]
(root/'opaque-hulls.json').write_text(json.dumps(result,separators=(',',':'))+'\n');print('Prepared',len(result),'compact opaque hulls')
