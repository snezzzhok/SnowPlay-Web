#!/usr/bin/env python3
"""Repeated real workbench open/cancel, isolated settings; checks cleanup/cache plateau."""
from pathlib import Path
import json,subprocess,tempfile,time,urllib.request,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-workbench-stress-') as folder:
 f=Path(folder);log=open(f/'app.log','w+');config=json.loads((root/'Presets/play.json').read_text());config.update(intensity=.7,automaticCleaning=0,windowSnow=True)
 (f/'settings.json').write_text(json.dumps(config))
 app=subprocess.Popen([os.environ.get('SNOWPLAY_BINARY',str(root/'dist/SnowPlay.app/Contents/MacOS/SnowPlay')),'--config',str(f/'settings.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  end=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<end:time.sleep(.1)
  url=(f/'url').read_text().strip();token=''
  def call(path='/api/state',body=None):
   request=urllib.request.Request(url+path,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json','Origin':url,'X-SnowPlay-Token':token})
   with urllib.request.urlopen(request,timeout=4) as r:return json.load(r)
  token=call()['sessionToken'];samples=[]
  for i in range(12):
   call('/api/action',{'action':'snowballs'});end=time.monotonic()+8
   while time.monotonic()<end and not call()['sculpting']['seeded']:time.sleep(.1)
   assert call()['sculpting']['seeded']
   done=call('/api/action',{'action':'done'});assert not done['sculpting']['active'] and not any(x.startswith('sculpt-') for x in done['surfaceIDs'])
   time.sleep(1.05);samples.append(call()['performance'])
  # Three initial cycles warm framework caches; later physical footprint must not grow per session.
  a=samples[3]['physicalFootprintMB'];b=samples[-1]['physicalFootprintMB'];growth=b-a
  assert growth<15,('Unexpected retained memory after repeated cleanup',growth)
  report={'passed':True,'cycles':12,'postWarmupPhysicalFootprintGrowthMB':growth,'maxResidentMB':max(x['residentMB'] for x in samples),'longSoakTested':False,'samples':samples}
  (root/'Docs/workbench-stress-result.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='samples'},indent=2))
 finally:app.terminate();app.wait(timeout=5)
