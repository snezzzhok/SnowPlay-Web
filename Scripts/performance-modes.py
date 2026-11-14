#!/usr/bin/env python3
"""Measured native release process in a real macOS session; no GPU/frame-display claim."""
import json,statistics,subprocess,tempfile,time,urllib.request,os
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-modes-') as folder:
 f=Path(folder);log=open(f/'app.log','w+')
 app=subprocess.Popen([str(root/'dist/SnowPlay.app/Contents/MacOS/SnowPlay'),'--config',str(f/'settings.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  deadline=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<deadline:time.sleep(.1)
  url=(f/'url').read_text().strip();token=''
  def call(path='/api/state',body=None):
   req=urllib.request.Request(url+path,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json','Origin':url,'X-SnowPlay-Token':token})
   with urllib.request.urlopen(req,timeout=4) as r:return json.load(r)
  token=call()['sessionToken'];results={}
  activeDeadline=time.monotonic()+40
  while call()['systemPaused']:
   if time.monotonic()>activeDeadline:raise RuntimeError('macOS graphical session is paused; cannot measure active rendering')
   time.sleep(.2)
  def cpu():
   value=subprocess.check_output(['ps','-p',str(app.pid),'-o','time='],text=True).strip();m,s=value.split(':');return int(m)*60+float(s)
  for mode in ['focus','balanced','play']:
   state=call('/api/action',{'action':mode});c=state['config'];c.update(automaticCleaning=0,tree=False,garland=False,windowSnow=True)
   if mode=='play' and os.environ.get('SNOWPLAY_PROFILE_PEAK_SNOW')=='1':c['intensity']=1
   world=os.environ.get('SNOWPLAY_PROFILE_WORLD')=='1'
   if world:
    c.update(tree=True,garland=True,groundSnow=True)
    for key in state.get('surfaceIDs',[]):
     if key.startswith('ground-'):
      c.setdefault('placements',{})[key[7:]]={'tree':{'x':.8,'y':.8},'garland':[{'x':.12,'y':.15},{'x':.5,'y':.1},{'x':.85,'y':.15}],'garlandTarget':'desktop'}
   call('/api/config',c)
   time.sleep(4)
   if mode=='play':
    call('/api/action',{'action':'delivery'})
    if not world:call('/api/action',{'action':'snowballs'})
    call('/api/action',{'action':'yeti-play' if world else 'clean'})
   start=time.monotonic();a=cpu();samples=[]
   for index in range(20):
    if world and mode=='play' and index==10:call('/api/action',{'action':'clean'})
    sample=call()
    if sample['systemPaused']:raise RuntimeError('Performance measurement interrupted by a paused macOS session')
    samples.append(sample);time.sleep(1)
   elapsed=time.monotonic()-start;osCPU=(cpu()-a)/elapsed*100;perf=[s['performance'] for s in samples]
   def metric(key):return {'median':statistics.median(p[key] for p in perf),'max':max(p[key] for p in perf)}
   result={'intensity':c['intensity'],'warmupSeconds':4,'sampleSeconds':elapsed,'displays':samples[-1]['displays'],'windows':samples[-1]['windows'],'accessibility':samples[-1]['accessibility'],'battery':perf[-1]['battery'],'particles':perf[-1]['particles'],'targetFPS':perf[-1]['targetFPS'],'systemPaused':samples[-1]['systemPaused'],'deliveryObserved':any(s['deliveryState']['flying'] for s in samples),'workbenchObserved':any(s['sculpting']['active'] for s in samples),'osCPUPercentOneCore':osCPU,'cpuPercentOneCore':metric('cpuPercentOneCore'),'residentMB':metric('residentMB'),'physicalFootprintMB':metric('physicalFootprintMB'),'simulationHz':metric('simulationHz'),'p95SimulationFrameMS':metric('p95FrameMS'),'rawSamples':perf}
   assert any(p['simulating'] for p in perf) and not result['systemPaused']
   result['characterObserved']=any(s.get('characters') for s in samples)
   result['garlandEnabled']=c['garland']
   results[mode]=result;print(mode,json.dumps({k:v for k,v in result.items() if k!='rawSamples'}),flush=True)
  call('/api/action',{'action':'done'});call('/api/action',{'action':'pause'});time.sleep(1);a=cpu();start=time.monotonic();time.sleep(3);paused=(cpu()-a)/(time.monotonic()-start)*100
  report={'build':'release, ad-hoc signature','date':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'modes':results,'pausedCPUPercentOneCore':paused,'gpuMeasured':False,'displayedFramesMeasured':False,'longSoakTested':False,'scenario':'Focus and Balanced snowfall + window/Dock banks; Play additionally requests Santa/plow and keeps the sculpting workbench active. Delivery visibility recorded from native state; no mouse rolling or hat interaction in this profile.'}
  if world:report['scenario']='Each mode: snowfall + window/Dock/ground banks, tree and three-pin Verlet garland. Play at requested intensity additionally requests Santa, one 50/50 Yeti game, and plow at sample 10. No editor takes user input during this profile. Character/delivery visibility recorded from native state; no user pointer input.'
  report['simulationIntervalNote']='Legacy p95SimulationFrameMS is the interval between simulation ticks, including timer wait. It is not computation duration or a measurement of presented GPU frames.'
  output=root/os.environ.get('SNOWPLAY_PERFORMANCE_OUTPUT','Docs/asset-performance-result.json');output.write_text(json.dumps(report,indent=2)+'\n');print('Saved '+str(output),flush=True)
 finally:
  app.terminate();app.wait(timeout=5)
