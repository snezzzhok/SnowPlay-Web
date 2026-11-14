#!/usr/bin/env python3
"""Release native app measurement. Samples process CPU/RSS and simulation pacing.
No GPU or displayed-frame throughput claim. No screenshot capture.
"""
import json,statistics,subprocess,tempfile,time,urllib.request,os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-perf-') as folder:
 f=Path(folder);log=open(f/'native.log','w+')
 binary=os.environ.get('SNOWPLAY_BINARY',str(root/'dist/SnowPlay.app/Contents/MacOS/SnowPlay'))
 app=subprocess.Popen([binary,'--config',str(f/'config.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],cwd=root,stdout=log,stderr=log)
 try:
  deadline=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<deadline:time.sleep(.1)
  url=(f/'url').read_text()
  def call(path='/api/state',body=None):
   req=urllib.request.Request(url+path,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json','Origin':url,'X-SnowPlay-Token':token} if body is not None else {})
   with urllib.request.urlopen(req,timeout=4) as r:return json.load(r)
  state=call();token=state['sessionToken']; samples=[]
  # Warm up SpriteKit + graphics driver and initial AX metadata attachment.
  time.sleep(5)
  for _ in range(20):
   samples.append(call());time.sleep(1)
  call('/api/action',{'action':'pause'})
  # The internal monitor intentionally stops during Pause. Use OS CPU deltas externally.
  def cpu_seconds():
   value=subprocess.check_output(['ps','-p',str(app.pid),'-o','time='],text=True).strip()
   m,s=value.split(':');return int(m)*60+float(s)
  a=cpu_seconds();start=time.monotonic();time.sleep(3);paused_cpu=(cpu_seconds()-a)/(time.monotonic()-start)*100
  perf=[s['performance'] for s in samples]
  result={'build':'release, ad-hoc signed','warmupSeconds':5,'sampleSeconds':20,'displays':samples[-1]['displays'],'observedWindows':samples[-1]['windows'],'battery':perf[-1]['battery'],'particles':perf[-1]['particles'],'targetFPS':perf[-1]['targetFPS'],
   'activeSimulationObserved':any(p.get('simulating',False) for p in perf),'systemPaused':samples[-1].get('systemPaused',False),
   'cpuPercentOneCore':{'median':statistics.median(p['cpuPercentOneCore'] for p in perf),'max':max(p['cpuPercentOneCore'] for p in perf)},
   'residentMB':{'median':statistics.median(p['residentMB'] for p in perf),'max':max(p['residentMB'] for p in perf)},
   'physicalFootprintMB':{'median':statistics.median(p.get('physicalFootprintMB',0) for p in perf),'max':max(p.get('physicalFootprintMB',0) for p in perf)},
   'simulationHzMedian':statistics.median(p['simulationHz'] for p in perf),'simulationP95FrameMS':statistics.median(p['p95FrameMS'] for p in perf),'pausedCPUPercent':paused_cpu,
   'gpuMeasured':False,'hoursLongSoakTested':False,'rawSamples':perf}
  (root/'Docs/performance-result.json').write_text(json.dumps(result,indent=2)+'\n')
  print(json.dumps({k:v for k,v in result.items() if k!='rawSamples'},indent=2))
 finally:
  app.terminate()
  try:app.wait(timeout=4)
  except subprocess.TimeoutExpired:app.kill();app.wait()
