#!/usr/bin/env python3
"""Compare packaged binaries with isolated copies of the same preferences, no UI actions.
Window layout must remain unchanged. Values are self-reported CPU (one core), RSS and
callback timings, not presented GPU frames. Run binaries sequentially, never concurrently.
"""
from pathlib import Path
import json,os,statistics,subprocess,sys,tempfile,time,urllib.request
root=Path(__file__).resolve().parents[1]
binary=Path(sys.argv[1]).resolve();output=Path(sys.argv[2]);base=json.loads((root/'.build/optimization-user-config-before.json').read_text())
result={'scope':'Actual packaged native app, isolated preferences, same existing window layout and hats. Sequential runs, 5s warmup + 15 samples at 1s. CPU is percent of one core; GPU presentation not measured.','cases':{}}
for name in ['idle-current','snow-55']:
 with tempfile.TemporaryDirectory(prefix='snowplay-benchmark-') as folder:
  folder=Path(folder);cfg=dict(base)
  if name=='snow-55':cfg['snow']=True;cfg['intensity']=.55
  (folder/'settings.json').write_text(json.dumps(cfg));env=dict(os.environ);env.pop('SNOWPLAY_RESOURCE_ROOT',None)
  with open(folder/'log','w') as log:
   p=subprocess.Popen([str(binary),'--config',str(folder/'settings.json'),'--no-auto-delivery','--control-url-file',str(folder/'url')],cwd=root,stdin=subprocess.DEVNULL,stdout=log,stderr=log)
   try:
    deadline=time.monotonic()+15
    while not (folder/'url').exists() and time.monotonic()<deadline:
     if p.poll() is not None:raise RuntimeError('benchmark process exited')
     time.sleep(.1)
    url=(folder/'url').read_text().strip();time.sleep(5);rows=[]
    for i in range(15):
     with urllib.request.urlopen(url+'/api/state',timeout=4) as response:s=json.load(response)
     if s['systemPaused']:raise RuntimeError('graphics session paused; do not report visible performance')
     rows.append({'performance':s['performance'],'rendering':s['rendering'],'tracking':s.get('tracking'),'windows':s['windows'],'dockVisible':s['dockVisible'],'editor':s['editor']});time.sleep(1)
    perf=[r['performance'] for r in rows]
    result['cases'][name]={'settings':{k:s['config'][k] for k in ['intensity','snow','mode','snowSpeed','windowSnow','frost','dockHats']},'samples':rows,'summary':{'cpuMedianOneCore':statistics.median(r['cpuPercentOneCore'] for r in perf),'cpuMeanOneCore':statistics.mean(r['cpuPercentOneCore'] for r in perf),'rssMedianMB':statistics.median(r['residentMB'] for r in perf),'footprintMedianMB':statistics.median(r['physicalFootprintMB'] for r in perf),'targetFPS':perf[-1]['targetFPS'],'simulationHzMedian':statistics.median(r['simulationHz'] for r in perf),'p95TickMSMedian':statistics.median(r['p95FrameMS'] for r in perf),'particles':perf[-1]['particles']}}
    output.write_text(json.dumps(result,indent=2)+'\n');print(name,json.dumps(result['cases'][name]['summary']),flush=True)
   finally:p.terminate();p.wait(timeout=5)
