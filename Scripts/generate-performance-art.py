from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]/'Sources/SnowPlay/Resources/SnowPlayAssets';folder=root/'World';m=json.loads((folder/'manifest.json').read_text());art={}
for name,color,light in [('red','#bd5060','#ef9d91'),('green','#3b8069','#9bc9a2'),('blue','#517caa','#a9cde4'),('gold','#b58242','#f7d48b'),('purple','#81679b','#c5abd5'),('fur','#cbe3ee','#fff')]:
 art['story_rig_'+name]=(24,64,f'<defs><linearGradient id="c" x2="1" y2="0"><stop stop-color="{light}"/><stop offset="1" stop-color="{color}"/></linearGradient></defs><rect x="4" y="2" width="16" height="60" rx="8" fill="url(#c)"/><path d="M8 10V44" stroke="{light}" stroke-width="2" stroke-linecap="round" opacity=".5"/>')
 art['story_friend_'+name]=(128,128,f'<path d="M36 61Q65 77 94 60L94 73Q64 87 36 74Z" fill="{color}" stroke="{light}" stroke-width="2"/><path d="M74 74H91L87 102H73Z" fill="{color}"/><path d="M76 87H88M75 96H87" stroke="{light}" stroke-width="2"/>')
art['story_rig_big_gnome']=(128,128,'<defs><linearGradient id="c" x2=".8" y2="1"><stop stop-color="#ddaa75"/><stop offset="1" stop-color="#b65456"/></linearGradient></defs><path d="M39 58Q17 65 16 96Q16 119 64 120Q112 119 112 96Q112 66 89 58Z" fill="url(#c)" stroke="#94505a" stroke-width="2"/><path d="M21 100Q64 112 108 100" fill="none" stroke="#69505a" stroke-width="9"/><rect x="58" y="100" width="14" height="10" rx="2" fill="#f4d58c"/><circle cx="64" cy="80" r="3" fill="#ffe0a3"/>')
art['story_rig_giant_yeti']=(128,128,'<defs><linearGradient id="f" x2=".6" y2="1"><stop stop-color="#fff9e8"/><stop offset="1" stop-color="#b9d9e8"/></linearGradient></defs><path d="M36 57Q16 76 19 99L14 104L25 108Q30 123 49 115Q66 126 83 115Q103 122 109 105L116 100L108 95Q111 70 90 57Z" fill="url(#f)" stroke="#9dbdc9" stroke-width="2"/><ellipse cx="64" cy="91" rx="29" ry="23" fill="#e5eff0"/><path d="M40 65Q64 84 91 63" stroke="#cead75" stroke-width="8" fill="none"/>')
art['story_rig_freckles']=(128,128,'<g fill="#98a8b9" opacity=".7"><circle cx="43" cy="44" r="2"/><circle cx="48" cy="47" r="1.5"/><circle cx="82" cy="44" r="2"/><circle cx="77" cy="47" r="1.5"/></g>')
for side,d in [('left','M80 131L53 118L40 98M52 118L35 120'),('right','M177 130L207 114L217 90M207 114L223 113')]:
 art['story_rig_snowman_'+side]=(256,256,f'<path d="{d}" fill="none" stroke="#b77545" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>')
ids=set(art);m['assets']=[a for a in m['assets'] if a['id'] not in ids]
for id,(w,h,body) in art.items():
 (folder/(id+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>\n')
 m['assets'].append({'id':id,'category':'Christmas','svg':'World/'+id+'.svg','preview':'Prepared/'+id+'@2x.png','viewBox':[0,0,w,h],'size':{'width':w,'height':h},'anchor':{'x':.5,'y':.5},'components':[],'description':'Story performance rig component, original SnowPlay vector'})
m['asset_count']=len(m['assets']);(folder/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');print('Created',len(art),'shared rig and giant components')
