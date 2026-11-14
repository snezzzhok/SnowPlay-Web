#!/usr/bin/env python3
"""Real socket test against the native executable. Uses isolated settings."""
import json, os, subprocess, tempfile, time, urllib.request, urllib.error, socket
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-api-') as folder:
 f=Path(folder); url_file=f/'url'; log=open(f/'native.log','w+')
 binary=os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay'))
 process=subprocess.Popen([binary,'--config',str(f/'config.json'),'--no-auto-delivery','--control-url-file',str(url_file)],cwd=root,stdout=log,stderr=log)
 try:
  deadline=time.monotonic()+15
  while not url_file.exists() and time.monotonic()<deadline:
   if process.poll() is not None: raise RuntimeError('native app exited before server startup')
   time.sleep(.1)
  url=url_file.read_text(); port=int(url.rsplit(':',1)[1]); print('Native loopback server started')
  def call(path,body=None,headers=None,expected=200):
   data=None if body is None else json.dumps(body).encode()
   h={'Content-Type':'application/json'};h.update(headers or {})
   req=urllib.request.Request(url+path,data=data,headers=h)
   try:
    with urllib.request.urlopen(req,timeout=4) as response:
     code=response.status; payload=response.read(); assert response.headers.get('Access-Control-Allow-Origin') is None
   except urllib.error.HTTPError as e: code=e.code;payload=e.read()
   assert code==expected,(path,code,expected,payload[:300]);return payload
  state=json.loads(call('/api/state')); token=state['sessionToken']; valid={'Origin':url,'X-SnowPlay-Token':token}
  assert 'SnowPlay'.encode() in call('/')
  assert b'wind-control' in call('/') and b'Roll &amp; throw' in call('/') and b'Move snowmen' in call('/')
  assert b'id="testing"' not in call('/') and b'id="reset"' not in call('/')
  assert b'pointerdown' in call('/app.js') and b'/api/checks' in call('/testing.js')
  assert json.loads(call('/api/checks'))=={'current':0,'results':{}}
  call('/api/checks',{'current':1,'results':{}},expected=403)
  progress=json.loads(call('/api/checks',{'current':7,'results':{'8':{'status':'failed','note':'Timer'},'20':{'status':'passed','note':''}}},valid))
  assert progress=={'current':7,'results':{'8':{'status':'failed','note':'Timer'}}}
  assert json.loads(call('/api/checks'))==progress
  call('/api/checks',{'wrong':True},valid,400)
  assert b'windowSnow' in call('/') and b'mascot' not in call('/')
  call('/api/action',{'action':'garland'},valid)
  call('/api/action',{'action':'done'},valid)
  if not state['systemPaused']:
   call('/api/action',{'action':'play'},valid)
   playing=json.loads(call('/api/action',{'action':'snowball-play'},valid))
   assert playing['editor']=='snowballPlay' and playing['looseSnowballs']==0
   stopped=json.loads(call('/api/action',{'action':'done'},valid))
   assert stopped['editor']=='none' and not stopped['config']['interaction']
   moving=json.loads(call('/api/action',{'action':'move-snowmen'},valid))
   assert moving['editor']=='snowmen'
   call('/api/action',{'action':'done'},valid)
  placementConfig=json.loads(call('/api/state'))['config']
  placementConfig['placements']['fixture']={'tree':{'x':.5,'y':.7},'garland':[]}
  call('/api/config',placementConfig,valid)
  treeGarland=json.loads(call('/api/action',{'action':'garland-tree'},valid))
  assert treeGarland['config']['placements']['fixture']['garlandTarget']=='tree'
  desktopGarland=json.loads(call('/api/action',{'action':'garland'},valid))
  assert desktopGarland['config']['placements']['fixture']['garlandTarget']=='desktop'
  assert desktopGarland['config']['placements']['fixture']['garland']==[]
  call('/api/action',{'action':'done'},valid)
  strandConfig=desktopGarland['config'];strandConfig['placements']['fixture']['garland']=[{'x':.2,'y':.1},{'x':.8,'y':.1}]
  call('/api/config',strandConfig,valid)
  multi=json.loads(call('/api/action',{'action':'new-garland'},valid))['config']['placements']['fixture']
  assert multi['garland']==[] and len(multi['extraGarlands'])==1
  strandID=multi['extraGarlands'][0]['id']
  call('/api/action',{'action':'done'},valid)
  removed=json.loads(call('/api/action',{'action':'remove-garland-strand','id':strandID},valid))['config']['placements']['fixture']
  assert removed['extraGarlands']==[]
  charmConfig=desktopGarland['config'];charmConfig['placements']['fixture']['ornaments']=[{'id':'tree_slot_0','anchor':{'x':.4,'y':.4},'hidden':True}];charmConfig['treeToy1']='candy'
  changedCharm=json.loads(call('/api/config',charmConfig,valid))
  assert not changedCharm['config']['placements']['fixture']['ornaments'][0]['hidden']
  ids=json.loads(call('/api/assets'))['ids'];assert len(ids)==126
  assert call('/assets/christmas_tree').startswith(b'\x89PNG')
  assert call('/assets/snowplow_complete').startswith(b'\x89PNG') and call('/assets/snowplow').startswith(b'\x89PNG')
  import re
  for image in re.findall(rb'<img[^>]+src="([^"]+)"',call('/')):assert call(image.decode()).startswith(b'\x89PNG'),image
  assert all(x in ids for x in ['truck_body','gnome_head','yeti_palm','snowman_face_closed'])
  assert b'snowman_face_closed' in call('/models')
  call('/assets/../../Package.swift',expected=404)
  call('/assets/not-a-model',expected=404)
  assert state['config']['windowEffectDuration']==4
  assert b'fetch(' in call('/app.js')
  call('/api/action',{'action':'pause'},expected=403)
  call('/api/action',{'action':'pause'},{'Origin':'https://evil.example','X-SnowPlay-Token':token},403)
  call('/api/action',{'action':'pause'},{'Origin':url,'X-SnowPlay-Token':'wrong'},403)
  call('/api/state',headers={'Host':'evil.example:'+str(port)},expected=403)
  call('/api/state',headers={'Sec-Fetch-Site':'cross-site'},expected=403)
  call('/api/state',headers={'Origin':'https://evil.example'},expected=403)
  assert json.loads(call('/api/action',{'action':'pause'},valid))['paused']
  config=state['config'];config['intensity']=.42;config['accumulationHeight']=99;config['windowEffectDuration']=99;config['windowSnow']=True;config['mascot']='mochi'
  changed=json.loads(call('/api/config',config,valid));assert changed['config']['intensity']==.42;assert changed['config']['accumulationHeight']==12;assert changed['config']['windowEffectDuration']==5
  assert changed['config']['windowSnow'] and changed['config']['mascot']=='none'
  for key in ['dockHats','snowSpeed']:config.pop(key,None)
  assert json.loads(call('/api/config',config,valid))['config']['snowSpeed']==1
  call('/api/action',{'action':'unknown'},valid,400)
  call('/api/config',{'snow':True},valid,400)
  call('/../Package.swift',expected=404)
  # Raw duplicate Host request must not be interpreted differently by the parser.
  with socket.create_connection(('127.0.0.1',port)) as client:
   client.sendall(f'GET /api/state HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nHost: evil.example\r\n\r\n'.encode()); assert b'400' in client.recv(4096)
  assert not json.loads(call('/api/action',{'action':'resume'},valid))['paused']
  call('/api/action',{'action':'balanced'},valid)
  config=json.loads(call('/api/state'))['config'];config['yetiEnabled']=True
  assert not json.loads(call('/api/config',config,valid))['config']['yetiEnabled']
  yeti=json.loads(call('/api/action',{'action':'yeti-play'},valid));assert yeti['living']['activity'].get('kind')=='surprise' or bool(yeti['diagnostic'])
  call('/api/action',{'action':'cancel-story'},valid)
  call('/api/action',{'action':'pause'},valid)
  reset=json.loads(call('/api/action',{'action':'reset-settings'},valid))
  assert reset['config']['intensity']==.35 and reset['config']['snowSpeed']==1
  assert not reset['config']['windowSnow'] and not reset['config']['frost'] and not reset['paused']
  assert reset['config']['placements']=={} and reset['config']['mode']=='balanced'
  time.sleep(3)
  final=json.loads(call('/api/state'));final.pop('sessionToken',None)
  (root/'Docs/api-smoke-result.json').write_text(json.dumps(final,indent=2)+'\n')
  print('PASS: static resources, config/clamping, pause/resume, actual defaults reset, explicit Yeti activity, all preview images, token, Origin, Host, fetch-site, parser, invalid routes; no CORS')
  print(json.dumps(final.get('performance',{}),indent=2))
 finally:
  process.terminate()
  try: process.wait(timeout=4)
  except subprocess.TimeoutExpired: process.kill();process.wait()
  log.seek(0); messages=log.read()
  if messages: print('Native log:',messages[-3000:])
