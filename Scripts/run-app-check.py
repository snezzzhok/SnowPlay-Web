#!/usr/bin/env python3
"""Link a small owned fixture against the already-built debug app (no app entry point)."""
from pathlib import Path
import sys,subprocess,tempfile,os
root=Path(__file__).resolve().parents[1];source=Path(sys.argv[1]);output=root/'.build'/source.stem
objects=[str(p) for p in (root/'.build/debug/SnowPlay.build').glob('*.o') if p.name!='main.swift.o']+[str(p) for p in (root/'.build/debug/SnowCore.build').glob('*.o')]
subprocess.run([str(root/'.build/toolchain/swiftc'),'-parse-as-library','-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-target','arm64-apple-macosx13.0','-I',str(root/'.build/debug/Modules'),str(source),*objects,'-o',str(output)],cwd=root,check=True)
if '--build-only' not in sys.argv:
 with tempfile.TemporaryDirectory(prefix='snowplay-owned-check-') as folder:
  subprocess.run([str(output),'--config',str(Path(folder)/'settings.json')],cwd=root,env=dict(os.environ,SNOWPLAY_RESOURCE_ROOT=str(root/'Sources/SnowPlay/Resources')),check=True)
