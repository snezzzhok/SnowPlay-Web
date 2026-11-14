#!/usr/bin/env python3
"""Test the packaged app outside this checkout, with isolated settings and no resource override."""
from pathlib import Path
import subprocess,tempfile,time,json,urllib.request,os
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='snowplay-clean-bundle-') as folder:
 f=Path(folder);bundle=f/'SnowPlay.app';subprocess.run(['ditto',str(root/'dist/SnowPlay.app'),str(bundle)],check=True)
 env=dict(os.environ);env.pop('SNOWPLAY_RESOURCE_ROOT',None)
 with open(f/'app.log','w') as log:
  app=subprocess.Popen([str(bundle/'Contents/MacOS/SnowPlay'),'--config',str(f/'settings.json'),'--control-url-file',str(f/'url')],cwd=f,env=env,stdout=log,stderr=log)
  try:
   deadline=time.monotonic()+15
   while not (f/'url').exists() and time.monotonic()<deadline:time.sleep(.1)
   url=(f/'url').read_text().strip()
   def get(path):
    with urllib.request.urlopen(url+path,timeout=5) as r:return r.read()
   ids=json.loads(get('/api/assets'))['ids'];assert len(ids)==126
   for ident in ids:assert get('/assets/'+ident).startswith(b'\x89PNG\r\n\x1a\n'),ident
   assert get('/assets/snowplow')==get('/assets/snowplow_complete')
   page=get('/');assert b'Build a snowman' in page and b'lang="en"' in page and b'id="testing"' not in page
   assert b'truck_body' in get('/models') and b'snowman_face_closed' in get('/models')
   result={'passed':True,'packagedAppOutsideCheckout':True,'resourceEnvironmentOverride':False,'registeredPNGPreviews':len(ids),'snowplowAlias':True,'newModelsPresent':True,'liveGPUFramesTested':False}
   (root/'Docs/living-clean-bundle-result.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: copied packaged app outside repository; all 126 PNGs, corrected snowplow alias, new native panel/catalogue; no source-resource fallback')
  finally:app.terminate();app.wait(timeout=5)
