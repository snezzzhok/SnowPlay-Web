#!/usr/bin/env python3
"""Prepare pictures from the project's original exports for the explanation gallery."""
from pathlib import Path
from PIL import Image
from io import BytesIO
import base64,json
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'LegacyAssets/manifest.json').read_text())
def url(image):
 buffer=BytesIO();image.save(buffer,format='PNG',optimize=True)
 return 'data:image/png;base64,'+base64.b64encode(buffer.getvalue()).decode()
art={name:url(Image.open(root/'Assets'/entry['png'])) for name,entry in manifest.items()}
thumbs={}
for name,entry in manifest.items():
 image=Image.open(root/'Assets'/entry['png']);box=image.getbbox()
 if box:image=image.crop((max(0,box[0]-3),max(0,box[1]-3),min(image.width,box[2]+3),min(image.height,box[3]+3)))
 thumbs[name]=url(image)
models=[
 {'id':'tree','name':'Ёлка','size':'84 pt','layers':['tree_shadow','tree_trunk','tree_body','ornaments','tree_lights','tree_snow','tree_star'],'detail':'Снег на ветках; размещение на свободном рабочем столе.'},
 {'id':'snowman','name':'Снеговик','size':'54 pt','layers':['snowman_base','snowman_middle','snowman_head','snowman_details'],'detail':'Собирается из трёх снежных комов.'},
 {'id':'plow','name':'Снегоуборщик','size':'62 pt','layers':['plow_body','plow_wheels'],'detail':'За 4 секунды проходит вдоль Dock и очищает снег.'},
 {'id':'santa','name':'Санта и сани','size':'72 pt','layers':['sleigh_body','santa_bag','santa_body'],'detail':'Фоновая доставка без оленей; один подарок.'},
 {'id':'gift','name':'Подарок','size':'≈20 pt коробка','layers':['gift_box','gift_lid'],'detail':'Открывается двойным кликом; показывает новогодний таймер.'},
 {'id':'parachute','name':'Парашют','size':'48 pt общий canvas','layers':['gift_box','gift_lid','parachute'],'detail':'Раскрывается после сброса и исчезает при посадке.'},
 {'id':'mochi','name':'Mochi','size':'40 pt canvas','layers':['mochi_idle_0'],'detail':'Белый мини-йети; четыре состояния.'},
 {'id':'puffy','name':'Puffy','size':'40 pt canvas','layers':['puffy_idle_0'],'detail':'Лиловый пушистик; четыре состояния.'},
 {'id':'bubi','name':'Bubi','size':'40 pt canvas','layers':['bubi_idle_0'],'detail':'Мятный зверёк; четыре состояния.'},
 {'id':'balls','name':'Снежные комы','size':'8–35 pt','layers':['snowball_small','snowball_medium','snowball_large'],'detail':'Растут за счёт снега, собранного с Dock.'},
 {'id':'garland','name':'Гирлянда','size':'лампы 3–5 pt','layers':['garland_bulb'],'detail':'Провод строится программно между точками крепления.'},
 {'id':'frost','name':'Иней','size':'зона 3–8 pt','layers':['frost_0','frost_1','frost_2','frost_3'],'detail':'Рост после 20–60 секунд неактивности; таяние за 0,5 секунды.'},
 {'id':'dots','name':'Падающий снег','size':'1–3 pt','layers':[f'snow_dot_{i}' for i in range(6)],'detail':'В приложении — мягкие программно нарисованные точки.'},
 {'id':'caps','name':'Снежные шапки','size':'5 pt по умолчанию','layers':[f'snow_cap_{i}' for i in range(4)],'detail':'В приложении профиль растёт из осевших частиц и рисуется программно.'}
]
for model in models:
 image=Image.new('RGBA',(288,160))
 if model['id'] in ['balls','frost','dots','caps']:
  layers=model['layers'];n=len(layers)
  for i,name in enumerate(layers):
   picture=Image.open(root/'LegacyAssets/PNG'/f'{name}.png')
   if model['id']=='balls':picture=picture.crop((26,26,70,70))
   elif model['id'] in ['frost','dots','caps']:
    box=picture.getbbox();picture=picture.crop(box)
   picture.thumbnail((int(260/n)-10,88),Image.Resampling.LANCZOS)
   if model['id']!='dots':
    target=max(20,int(260/n)-10);ratio=min(target/max(1,picture.width),88/max(1,picture.height));picture=picture.resize((max(1,round(picture.width*ratio)),max(1,round(picture.height*ratio))),Image.Resampling.LANCZOS)
   image.alpha_composite(picture,(int(14+i*260/n+(260/n-picture.width)/2),int(80-picture.height/2)))
 elif model['id']=='garland':
  from PIL import ImageDraw
  draw=ImageDraw.Draw(image);points=[(x,45+int(16*(1-((x-144)/125)**2))) for x in range(20,270)]
  draw.line(points,fill='#668477',width=2)
  for x in range(25,270,22):
   y=45+int(16*(1-((x-144)/125)**2));draw.ellipse((x-2,y+2,x+2,y+8),fill='#e4c47f')
 else:
  composite=Image.new('RGBA',(96,96))
  for name in model['layers']:composite.alpha_composite(Image.open(root/'LegacyAssets/PNG'/f'{name}.png'))
  composite=composite.resize((144,144),Image.Resampling.LANCZOS);image.alpha_composite(composite,(72,8))
 model['picture']=url(image)
data={'models':models,'art':art,'thumbs':thumbs,'layerNames':list(manifest)}
(root/'Docs/visualizations/showcase-data.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
print(f'{len(models)} model groups, {len(art)} original layer/frame exports, JSON bytes: {(root/"Docs/visualizations/showcase-data.json").stat().st_size}')
