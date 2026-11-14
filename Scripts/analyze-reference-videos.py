#!/usr/bin/env python3
"""Extract exact source frames and PTS-labelled sheets from the six supplied reels.
No browser credentials; source downloads are private study material, never app assets.
"""
import argparse, hashlib, json, math, subprocess
from pathlib import Path
from fractions import Fraction
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'Docs/Reference-Research'
IDS=['Dfoml0yis3P','DfSv9v1NwMb','Dfms7IoNkOP','Dfe_bS1tAnH','DfaegGeNZmh','DfnvIglK-Qp']
def probe(path):
 return json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_frames','-show_entries','stream=width,height,avg_frame_rate:frame=best_effort_timestamp_time:format=duration','-of','json',str(path)],text=True))
def sheets(ident,times,label,crop=None):
 video=BASE/'media'/f'{ident}.mp4';p=probe(video);pts=[float(f['best_effort_timestamp_time']) for f in p['frames']]
 indices=sorted(set(min(range(len(pts)),key=lambda i:abs(pts[i]-t)) for t in times));folder=BASE/'frames'/ident/label;folder.mkdir(parents=True,exist_ok=True)
 select='+'.join(f'eq(n,{i})' for i in indices)
 width=300 if crop else 240
 transform=(f'crop={crop[2]}:{crop[3]}:{crop[0]}:{crop[1]},' if crop else '')+f'scale={width}:-2'
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(video),'-vf',f'select={select.replace(",",chr(92)+",")},{transform}','-fps_mode','vfr',str(folder/'frame-%03d.png')],check=True)
 frames=sorted(folder.glob('frame-*.png'));assert len(frames)==len(indices)
 meta=[]
 font=ImageFont.truetype('/System/Library/Fonts/Menlo.ttc',13)
 for page in range(0,len(frames),15):
  subset=frames[page:page+15];h=Image.open(subset[0]).height+28;image=Image.new('RGB',(width*5,h*((len(subset)+4)//5)),(23,30,39));draw=ImageDraw.Draw(image)
  for j,f in enumerate(subset):
   i=indices[page+j];xy=(j%5*width,j//5*h);image.paste(Image.open(f),xy);draw.text((xy[0]+5,xy[1]+h-23),f'{pts[i]:06.3f}s  frame {i}',font=font,fill='white')
   meta.append({'frame':i,'pts':pts[i],'crop':crop,'file':str(f.relative_to(ROOT))})
  image.save(BASE/'frames'/f'{ident}-{label}-{page//15+1}.jpg',quality=91)
 (folder/'index.json').write_text(json.dumps(meta,indent=2)+'\n')
 return p,meta
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--id',choices=IDS);ap.add_argument('--range',nargs=3,type=float,metavar=('START','END','STEP'));ap.add_argument('--crop',nargs=4,type=int,metavar=('X','Y','WIDTH','HEIGHT'));args=ap.parse_args()
 registry=[]
 for ident in ([args.id] if args.id else IDS):
  path=BASE/'media'/f'{ident}.mp4'
  if not path.exists():registry.append({'id':ident,'status':'unavailable'});continue
  p=probe(path);duration=float(p['format']['duration'])
  if args.range:
   a,b,step=args.range;times=[a+i*step for i in range(int(math.floor((b-a)/step+1e-7))+1)];label=f'detail-{a:g}-{b:g}'
  else:times=list(range(0,int(duration)+1,2));label='overview'
  _,meta=sheets(ident,times,label,args.crop)
  d=json.loads((BASE/'media'/f'{ident}.info.json').read_text())
  registry.append({'id':ident,'url':f'https://www.instagram.com/reel/{ident}/','uploader':d.get('uploader'),'username':d.get('uploader_id'),'date':d.get('upload_date'),'duration':duration,'video':p['streams'][0],'sourceFrames':len(p['frames']),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'downloaded','samples':meta})
 if not args.range:(BASE/'sources.json').write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n')
 print(json.dumps([{'id':x['id'],'duration':x.get('duration'),'frames':x.get('sourceFrames'),'status':x['status']} for x in registry],ensure_ascii=False))
