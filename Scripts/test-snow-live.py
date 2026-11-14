#!/usr/bin/env python3
"""Actual unseeded high-density snowfall and Dock accumulation on this macOS session."""
from pathlib import Path
import json,os,subprocess,tempfile,time,urllib.request,statistics
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-real-snow-') as folder:
 f=Path(folder);config=json.loads((root/'Presets/play.json').read_text());config.update(intensity=1,maxParticles=1200,automaticCleaning=0,fps=30,windAngle=0,windStrength=0,tree=False,garland=False,frost=False,dockSnow=True,snow=True)
 (f/'settings.json').write_text(json.dumps(config));log=open(f/'native.log','w+')
 binary=os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay'))
 app=subprocess.Popen([binary,'--config',str(f/'settings.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],cwd=root,stdout=log,stderr=log)
 try:
  deadline=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<deadline:time.sleep(.1)
  url=(f/'url').read_text().strip();samples=[]
  for _ in range(10):
   with urllib.request.urlopen(url+'/api/state',timeout=4) as r:s=json.load(r)
   samples.append({k:s[k] for k in ['dockDetected','dockVisible','dockSnowVolume','fullscreenSuppressed','systemPaused','performance']});time.sleep(1)
  assert all(not s['fullscreenSuppressed'] and not s['systemPaused'] for s in samples),'Session/fullscreen suppressed; measurement inconclusive'
  assert max(s['performance'].get('particles',0) for s in samples)>=900,'100% is still capped below dense snowfall'
  assert any(s['dockDetected'] for s in samples),'Dock not detected'
  assert samples[-1]['dockSnowVolume']>100,'No real Dock accumulation'
  result={'build':'release' if '/dist/' in binary else 'debug','passed':True,'unseededActualSnow':True,'sampleSeconds':10,'maxParticles':max(s['performance'].get('particles',0) for s in samples),'finalDockVolume':samples[-1]['dockSnowVolume'],'autoHiddenObserved':any(not s['dockVisible'] for s in samples),'cpuMedianOneCore':statistics.median(s['performance'].get('cpuPercentOneCore',0) for s in samples[2:]),'rssMaxMB':max(s['performance'].get('residentMB',0) for s in samples),'gpuMeasured':False,'samples':samples}
  (root/'Docs/live-snow-fixes-result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='samples'},indent=2))
 finally:app.terminate();app.wait(timeout=5)
