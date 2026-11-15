from pathlib import Path
import json,html
folder=Path(__file__).resolve().parents[1]/'Docs/Stories-3-Demos';items=json.loads((folder/'recordings.json').read_text())['items']
page='''<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>SnowPlay · Stories 3</title><style>body{background:#122f40;color:#edf8f5;font:16px -apple-system,sans-serif;max-width:1050px;margin:36px auto;padding:20px}h1{font-size:36px}p{color:#b4cbd3;line-height:1.6}nav{display:flex;flex-wrap:wrap;gap:9px;margin:25px 0}a{color:#d3ede6;text-decoration:none;background:#264d59;border-radius:10px;padding:10px 12px}article{margin:50px 0;scroll-margin:20px}video{display:block;width:100%;max-height:75vh;border-radius:15px;background:#18374a}small{color:#a9c5cf}</style><h1>Little winter stories</h1><p>Native SnowPlay animations. No captions inside the scene. Choose a story, then press Play.</p><nav>'''
for i,item in enumerate(items):page+=f'<a href="#scene-{i}">{html.escape(item["title"])}'+(' · B' if item['variant'] else '')+'</a>'
page+='</nav>'
for i,item in enumerate(items):
 page+=f'<article id="scene-{i}"><h2>{html.escape(item["title"])}'+(' · Ending B' if item['variant'] else '')+f'</h2><video controls preload="none" poster="{item["id"]}-{item["variant"]}.png" src="{item["file"]}"></video><p><small>{item["seconds"]:.1f} s · isolated production AppKit / SpriteKit scene</small></p></article>'
(folder/'index.html').write_text(page);print('Built gallery for',len(items),'native videos')
