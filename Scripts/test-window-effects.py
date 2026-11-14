#!/usr/bin/env python3
"""Current request: real snow on window tops; move/maximize/minimize/restore/close."""
from pathlib import Path
import json,subprocess,tempfile,time,urllib.request,select,os,threading,statistics
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-window-snow-') as folder:
 f=Path(folder);log=open(f/'native.log','w+');fixture=None;samples=[]
 config=json.loads((root/'Presets/play.json').read_text());config.update(intensity=1,maxParticles=1000,automaticCleaning=0,windowSnow=True,windStrength=0,windAngle=0,accumulationHeight=8)
 (f/'config.json').write_text(json.dumps(config))
 binary=os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay'))
 app=subprocess.Popen([binary,'--config',str(f/'config.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  deadline=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<deadline:time.sleep(.1)
  url=(f/'url').read_text().strip()
  activeDeadline=time.monotonic()+40
  while True:
   with urllib.request.urlopen(url+'/api/state',timeout=4) as response:startup=json.load(response)
   if not startup['systemPaused'] and startup.get('performance',{}).get('simulating'):break
   if time.monotonic()>activeDeadline:raise RuntimeError('macOS graphical session is paused; unlock/wake the desktop for real window tests')
   time.sleep(.2)
  fixture=subprocess.Popen([str(root/'.build/window-fixture'),'--controlled'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True,bufsize=1)
  assert select.select([fixture.stdout],[],[],5)[0];json.loads(fixture.stdout.readline());prefix=f'window-{fixture.pid}-';fixtureEvents=[]
  def readFixture():
   for line in fixture.stdout:
    try:fixtureEvents.append(json.loads(line))
    except json.JSONDecodeError:pass
  threading.Thread(target=readFixture,daemon=True).start()
  def sample():
   with urllib.request.urlopen(url+'/api/state',timeout=4) as r:s=json.load(r)
   own=[w for w in s['windowSnowStates'] if w['id'].startswith(prefix)]
   samples.append({'windowSnow':s['config']['windowSnow'],'fullscreen':s['fullscreenSuppressed'],'systemPaused':s['systemPaused'],'particles':s['performance'].get('particles'),'windows':own,'profiles':[x for x in s.get('surfaceIDs',[]) if x.startswith(prefix)],'accessibility':s['accessibility'],'events':s['windowEvents']});return own
  def wait(predicate,seconds=5):
   end=time.monotonic()+seconds
   while time.monotonic()<end:
    state=sample()
    if predicate(state):
     for w in state:
      origin=w.get('snowOrigin',[])
      if origin:assert abs(origin[0]-w['frame']['x']-2)<.01 and abs(origin[1]-w['frame']['y']-.5)<.01,'Snow separated from window geometry'
     return state
    time.sleep(.1)
   (root/'Docs/window-snow-failed-attempt.json').write_text(json.dumps(samples,indent=2)+'\n')
   print('Last window sample:',json.dumps(samples[-1]))
   print('Last fixture events:',fixtureEvents[-4:])
   raise AssertionError('Window transition not observed')
  def command(name):fixture.stdin.write(name+'\n');fixture.stdin.flush()
  wait(lambda s:any(w['visible'] and w['accessibilityLinked'] and w['snowVolume']>50 for w in s),15)
  originalWidth=sample()[0]['frame']['width']
  command('move');wait(lambda s:any(w['visible'] and abs(w['frame']['x']-300)<3 and w['snowVolume']>0 for w in s))
  command('drag');errors=[];end=time.monotonic()+1.4
  while time.monotonic()<end:
   states=sample();latest=next((e for e in reversed(fixtureEvents) if e['event']=='drag-step'),None)
   if latest and states:errors.append(abs(states[0]['frame']['x']-latest['frame']['x']))
   time.sleep(.015)
  assert len(errors)>10 and statistics.quantiles(errors,n=20)[18]<=18 and max(errors)<=32,errors
  command('maximize');wait(lambda s:any(w['visible'] and w['frame']['width']>originalWidth+100 and w['snowVolume']>0 for w in s))
  command('minimize');wait(lambda s:any(w['phase']=='minimized' and not w['visible'] and w['snowVolume']<0.01 for w in s))
  command('restore');wait(lambda s:any(w['visible'] and w['restoreProgress']==1 and w['snowVolume']>0 for w in s))
  command('close');wait(lambda s:not s)
  assert not samples[-1]['profiles'],'Closed window retained a snow surface'
  result={'passed':True,'unseededWindowAccumulation':True,'moveMaximizeMinimizeRestoreClose':True,'minimizeDropsWholeCap':True,'fastGeometrySamples':len(errors),'p95GeometryDifferencePt':statistics.quantiles(errors,n=20)[18],'maxGeometryDifferencePt':max(errors),'samples':samples}
  (root/'Docs/floor-window-result.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: real NSWindow accumulates snow; move/maximize/minimize/restore/close retain or remove correct physical profiles')
 finally:
  if fixture and fixture.poll() is None:fixture.terminate();fixture.wait(timeout=4)
  app.terminate();app.wait(timeout=4)
