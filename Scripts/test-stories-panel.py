#!/usr/bin/env python3
from pathlib import Path
import subprocess,tempfile,time,os,json,urllib.request
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-stories-panel-') as folder:
 f=Path(folder);log=open(f/'app.log','w+');binary=os.environ.get('SNOWPLAY_BINARY',str(root/'.build/debug/SnowPlay'))
 app=subprocess.Popen([binary,'--config',str(f/'settings.json'),'--no-auto-stories','--control-url-file',str(f/'url')],stdout=log,stderr=log)
 try:
  for _ in range(150):
   if (f/'url').exists():break
   if app.poll() is not None:raise RuntimeError('App exited')
   time.sleep(.1)
  subprocess.run([str(root/'.build/stories-panel-check'),(f/'url').read_text().strip()],cwd=root,check=True,timeout=50)
  app.terminate();app.wait(timeout=5)
  settings=json.loads((f/'settings.json').read_text())['stories'];assert settings['frequency']=='rare' and settings['enabled'] is False and len(settings['enabledStories'])==8
  print('PASS: native on-disk story preferences; user settings untouched')
 finally:
  if app.poll() is None:app.terminate();app.wait(timeout=5)
