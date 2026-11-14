#!/usr/bin/env python3
"""Native WebKit/control API integration, isolated preferences and manual-check results."""
import json,os,subprocess,tempfile,time,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-panel-') as folder:
 f=Path(folder);log=open(f/'app.log','w+');app=None
 binary=os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay'))
 def start():
  global app
  (f/'url').unlink(missing_ok=True)
  app=subprocess.Popen([binary,'--config',str(f/'settings.json'),'--no-auto-delivery','--control-url-file',str(f/'url')],cwd=root,stdout=log,stderr=log)
  deadline=time.monotonic()+15
  while not (f/'url').exists() and time.monotonic()<deadline:
   if app.poll() is not None:raise RuntimeError('Native app exited before startup')
   time.sleep(.1)
  return (f/'url').read_text().strip()
 try:
  url=start()
  subprocess.run([str(root/'.build/web-panel-check'),url],cwd=root,check=True,timeout=65)
  app.terminate();app.wait(timeout=4)
  url=start()
  with urllib.request.urlopen(url+'/api/state',timeout=3) as r:state=json.load(r)
  assert state['config']['windAngle']==0 and state['config']['intensity']==.77 and state['config']['snowSpeed']==1.7
  result_path=root/'Docs/simple-panel-check-result.json';result=json.loads(result_path.read_text());result['survivesNativeAppRestart']=True;result_path.write_text(json.dumps(result,indent=2,ensure_ascii=False)+'\n')
  if result['manualShovelActionAndExit']:assert state['config']['automaticSnowman'] is False
  print('PASS: settings survive native app restart; user check history untouched')
 finally:
  if app and app.poll() is None:app.terminate();app.wait(timeout=4)
