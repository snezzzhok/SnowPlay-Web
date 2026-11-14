#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import subprocess
files=[str(p) for p in sorted(Path('Sources/SnowPlay').glob('*.swift')) if p.name!='main.swift']
subprocess.run(['.build/toolchain/swiftc','-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-target','arm64-apple-macosx13.0','-I','.build/debug/Modules',*files,'Scripts/InteractionCheck.swift',*map(str,Path('.build/debug/SnowCore.build').glob('*.o')),'-o','.build/interaction-check'],check=True)
PY
python3 - <<'PY'
from pathlib import Path
import subprocess,tempfile,json,os,select
root=Path.cwd()
with tempfile.TemporaryDirectory(prefix='snowplay-interaction-') as folder:
 with open(Path(folder)/'fixture.log','w') as log:
  fixture=subprocess.Popen(['.build/window-fixture','--controlled'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True,bufsize=1)
  try:
   assert select.select([fixture.stdout],[],[],5)[0]
   ready=json.loads(fixture.stdout.readline())
   env=dict(os.environ,SNOWPLAY_RESOURCE_ROOT=str(root/'Sources/SnowPlay/Resources'))
   subprocess.run(['.build/interaction-check','--config',str(Path(folder)/'settings.json'),'--fixture-pid',str(fixture.pid),'--no-auto-delivery'],env=env,check=True,timeout=25)
  finally:
   if fixture.poll() is None:fixture.terminate();fixture.wait(timeout=4)
PY
