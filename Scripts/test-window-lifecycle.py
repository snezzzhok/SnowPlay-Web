#!/usr/bin/env python3
"""Observe real public NSWindow lifecycle in a separate native fixture process.
Requires an unlocked GUI session and AX permission. Records rather than fabricates results.
"""
from pathlib import Path
import subprocess,tempfile,time,json,urllib.request
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-windows-') as folder:
 f=Path(folder);log=open(f/'app.log','w+')
 app=subprocess.Popen([str(root/'.build/debug/SnowPlay'),'--config',str(f/'config.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 fixture=None
 try:
  for _ in range(100):
   if (f/'url').exists():break
   time.sleep(.1)
  url=(f/'url').read_text()
  def state():
   with urllib.request.urlopen(url+'/api/state',timeout=3) as r:return json.load(r)
  before=state()
  fixture=subprocess.Popen([str(root/'.build/window-fixture'),'--auto'],stdout=log,stderr=log)
  samples=[]
  for _ in range(32):
   samples.append(state());time.sleep(.5)
  fixture.wait(timeout=3)
  after=state();events=after['windowEvents'];old=before['windowEvents']
  delta={k:events.get(k,0)-old.get(k,0) for k in set(events)|set(old)}
  result={'accessibility':after['accessibility'],'systemPaused':after.get('systemPaused',False),'eventsDuringFixture':delta,'sampledWindowCounts':[s['windows'] for s in samples],'note':'Counts include any concurrent user windows. Fixture performs move/resize/minimize/restore/hide/show/close using public NSWindow methods; no pixel capture.'}
  required=['created','moved','resized','minimized','restored','confirmedClosed']
  result['observedAllTransitions']=all(delta.get(k,0)>0 for k in required)
  (root/'Docs/window-integration-result.json').write_text(json.dumps(result,indent=2)+'\n')
  print(json.dumps(result,indent=2))
  if not result['observedAllTransitions']:
   print('INCOMPLETE: not all transitions observed. See feasibility report and manual checklist.')
   raise SystemExit(2)
 finally:
  for p in [fixture,app]:
   if p and p.poll() is None:p.terminate();p.wait(timeout=4)
