#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,time,os,json,urllib.request,urllib.error
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-sticker-test-') as folder:
 f=Path(folder);log=open(f/'app.log','w+');app=subprocess.Popen([os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay')),'--config',str(f/'settings.json'),'--no-auto-stories','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  for _ in range(150):
   if (f/'url').exists():break
   if app.poll() is not None:raise RuntimeError('App exited')
   time.sleep(.1)
  url=(f/'url').read_text().strip()
  def get(path):return json.load(urllib.request.urlopen(url+path))
  token=get('/api/state')['sessionToken']
  def post(body,expected=200):
   req=urllib.request.Request(url+'/api/stickers',data=json.dumps(body).encode(),headers={'Content-Type':'application/json','X-SnowPlay-Token':token,'Origin':url},method='POST')
   try:
    with urllib.request.urlopen(req) as r:assert r.status==expected;return json.load(r)
   except urllib.error.HTTPError as error:
    assert error.code==expected,(error.code,error.read());return {}
  initial=get('/api/state');assert len(initial['stickerStudio']['catalogue'])==20 and len(get('/api/assets')['ids'])==178
  for item in initial['stickerStudio']['catalogue']:
   data=urllib.request.urlopen(url+'/assets/'+item['id']).read();assert data[:8]==b'\x89PNG\r\n\x1a\n'
  preset=get('/api/stickers/preset');preset['settings']['items']=[{'id':str(i),'assetID':'sticker_bow','anchor':{'kind':'desktop','screen':'test','local':{'x':.5,'y':.5}},'scale':1,'rotation':0,'z':i,'animation':'none','visible':True,'locked':False,'flipX':False,'flipY':False,'segments':1,'text':''} for i in range(180)]
  items=preset['settings']['items'];preset['settings']['items']=[];post({'op':'import-begin','preset':preset})
  for i in range(0,len(items),24):post({'op':'import-part','items':items[i:i+24]})
  result=post({'op':'import-end'});assert len(result['config']['stickers']['items'])==180
  post({'op':'undo'});assert get('/api/state')['config']['stickers']['items']==[]
  post({'op':'redo'});assert len(get('/api/stickers/preset')['settings']['items'])==180
  post({'op':'import','preset':{'version':999}},400);post({'op':'import-end'},400)
  post({'op':'clear'});post({'op':'settings','defaultSize':64,'quality':'balanced','autoSnap':True,'animations':True})
  subprocess.run([str(root/'.build/sticker-panel-check'),url],cwd=root,check=True,timeout=40)
  app.terminate();app.wait(timeout=5);settings=json.loads((f/'settings.json').read_text())['stickers'];assert settings['defaultSize']==82 and settings['quality']=='low'
  (root/'Docs/sticker-studio-api-result.json').write_text(json.dumps({'passed':True,'all20Assets':True,'largePresetChunkImport180':True,'importAtomicUndoRedo':True,'badPresetRejected':True,'diskPersistence':True,'userPreferencesUntouched':True},indent=2)+'\n')
  print('PASS: 20 asset previews, chunked 180-item import, atomic Undo/Redo, validation and disk settings')
 finally:
  if app.poll() is None:app.terminate();app.wait(timeout=5)
