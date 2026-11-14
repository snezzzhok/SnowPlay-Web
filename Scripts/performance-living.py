#!/usr/bin/env python3
"""Real release-process CPU/RSS, simulation and native callback pacing. Isolated settings.
Never treats a locked desktop, simulation Hz, or a bitmap benchmark as presented GPU FPS.
"""
from pathlib import Path
import json,os,subprocess,tempfile,time,urllib.request,statistics
root=Path(__file__).resolve().parents[1]
output=root/'Docs/living-live-performance.json'
report={'scope':'Real macOS release app; native draw/update callbacks, CPU and resident memory. Not GPU presentation.','gpuMeasured':False,'presentedFramesMeasured':False,'scenarios':{}}
with tempfile.TemporaryDirectory(prefix='snowplay-living-perf-') as folder:
 f=Path(folder);log=open(f/'app.log','w+')
 app=subprocess.Popen([str(root/'dist/SnowPlay.app/Contents/MacOS/SnowPlay'),'--config',str(f/'settings.json'),'--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  end=time.monotonic()+12
  while not (f/'url').exists() and time.monotonic()<end:time.sleep(.1)
  url=(f/'url').read_text().strip();token=''
  def call(path='/api/state',body=None):
   req=urllib.request.Request(url+path,data=None if body is None else json.dumps(body).encode(),headers={'Content-Type':'application/json','Origin':url,'X-SnowPlay-Token':token})
   with urllib.request.urlopen(req,timeout=5) as r:return json.load(r)
  state=call();token=state['sessionToken'];time.sleep(.5);state=call()
  if state['systemPaused']:
   report.update(status='unavailable_locked_session',reason='macOS reports systemPaused=true. Unlock the Mac and rerun this script. No live FPS/CPU acceptance claim is made.')
  else:
   for mode in ['focus','balanced','play']:
    state=call('/api/action',{'action':mode});config=state['config'];config.update(windowSnow=False,garland=False,tree=False,automaticCleaning=0)
    if mode=='play':config['intensity']=1
    call('/api/config',config);time.sleep(5)
    samples=[]
    for _ in range(8):samples.append(call());time.sleep(1)
    if any(s['systemPaused'] for s in samples):raise RuntimeError('Session locked during measurement')
    perf=[s['performance'] for s in samples]
    report['scenarios'][mode]={'samples':len(samples),'cpuOneCoreMedian':statistics.median(p['cpuPercentOneCore'] for p in perf),'residentMBMedian':statistics.median(p['residentMB'] for p in perf),'particles':perf[-1]['particles'],'targetFPS':perf[-1]['targetFPS'],'nativeProbes':samples[-1]['rendering']}
   call('/api/action',{'action':'delivery'});call('/api/action',{'action':'clean'})
   peak=[]
   for _ in range(28):peak.append(call());time.sleep(.25)
   report['scenarios']['snowSantaPlow']={'samples':len(peak),'rawNativeProbes':[s['rendering'] for s in peak],'cpuOneCoreMax':max(s['performance']['cpuPercentOneCore'] for s in peak),'santaObserved':any(s['deliveryState']['flying'] for s in peak)}
   state=call('/api/action',{'action':'start-duel'})
   if state['living']['duel']:
    samples=[]
    for _ in range(88):
     s=call();samples.append(s)
     if s['systemPaused']:raise RuntimeError('Session locked during duel measurement')
     if s['living']['duel'].get('phase')=='playerAim':call('/api/action',{'action':'duel-aim','power':.5});call('/api/action',{'action':'duel-fire'})
     time.sleep(.25)
    report['scenarios']['duel']={'samples':len(samples),'nativeProbes':samples[-1]['rendering'],'cpuOneCoreMedian':statistics.median(s['performance']['cpuPercentOneCore'] for s in samples),'residentMBMax':max(s['performance']['residentMB'] for s in samples),'rawSamples':[{k:s[k] for k in ['performance','rendering','living']} for s in samples]}
    call('/api/action',{'action':'exit-duel'})
   else:report['scenarios']['duel']={'status':'unavailable_no_free_desktop_area','diagnostic':state['diagnostic']}
   call('/api/action',{'action':'pause'});time.sleep(.5)
   def cpu():
    value=subprocess.check_output(['ps','-p',str(app.pid),'-o','time='],text=True).strip();m,s=value.split(':');return int(m)*60+float(s)
   a=cpu();start=time.monotonic();time.sleep(3);report['pausedCPUOneCore']=(cpu()-a)/(time.monotonic()-start)*100
   report['status']='measured_callbacks_not_gpu'
 except Exception as e:report.update(status='incomplete',reason=str(e));raise
 finally:
  output.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
  app.terminate();app.wait(timeout=5)
print(json.dumps({k:v for k,v in report.items() if k!='scenarios'},ensure_ascii=False,indent=2))
