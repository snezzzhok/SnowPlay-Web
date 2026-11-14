#!/usr/bin/env python3
"""Real unseeded workbench stock/seed creation, with no requirement to reveal Dock."""
from pathlib import Path
import json,subprocess,tempfile,time,urllib.request,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-sculpt-live-') as folder:
 f=Path(folder);log=open(f/'app.log','w+')
 config=json.loads((root/'Presets/play.json').read_text());config.update(windowSnow=True,intensity=.8,maxParticles=1200,automaticCleaning=0,windAngle=0,windStrength=0)
 (f/'settings.json').write_text(json.dumps(config))
 app=subprocess.Popen([os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay')),'--config',str(f/'settings.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  end=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<end:time.sleep(.1)
  url=(f/'url').read_text().strip();token=''
  def call(path='/api/state',body=None):
   request=urllib.request.Request(url+path,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json','Origin':url,'X-SnowPlay-Token':token})
   with urllib.request.urlopen(request,timeout=4) as r:return json.load(r)
  token=call()['sessionToken'];call('/api/action',{'action':'snowballs'});samples=[]
  end=time.monotonic()+12
  while time.monotonic()<end:
   s=call();samples.append({'sculpting':s['sculpting'],'dockVisible':s['dockVisible'],'surfaceIDs':s['surfaceIDs']})
   if s['sculpting']['seeded']:break
   time.sleep(.2)
  assert samples[-1]['sculpting']['seeded'] and samples[-1]['sculpting']['active'],'Actual snow failed to create starter balls'
  done=call('/api/action',{'action':'done'});assert not done['sculpting']['active'] and not any(x.startswith('sculpt-') for x in done['surfaceIDs'])
  result={'passed':True,'unseededSnowStock':True,'secondsUntilSeeded':round(12-(end-time.monotonic()),2),'hiddenDockObserved':any(not x['dockVisible'] for x in samples),'cancelClearsSurface':True,'samples':samples}
  (root/'Docs/sculpt-live-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='samples'},indent=2))
 finally:app.terminate();app.wait(timeout=5)
