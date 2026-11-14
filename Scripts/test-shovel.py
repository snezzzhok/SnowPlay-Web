#!/usr/bin/env python3
"""Build and test manual sculpting with owned Cocoa events; does not require an unlocked desktop.
This deliberately does not claim a physical cursor/desktop gesture test.
"""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
subprocess.run(['Scripts/local-build.sh','build'],cwd=root,check=True)
objects=[str(p) for p in (root/'.build/debug/SnowPlay.build').glob('*.o') if p.name!='main.swift.o']+[str(p) for p in (root/'.build/debug/SnowCore.build').glob('*.o')]
subprocess.run([str(root/'.build/toolchain/swiftc'),'-parse-as-library','-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-target','arm64-apple-macosx13.0','-I',str(root/'.build/debug/Modules'),str(root/'Scripts/ShovelCheck.swift'),*objects,'-o',str(root/'.build/shovel-check')],cwd=root,check=True)
with tempfile.TemporaryDirectory(prefix='snowplay-shovel-') as folder:
 subprocess.run([str(root/'.build/shovel-check'),'--config',str(Path(folder)/'settings.json')],cwd=root,env=dict(os.environ,SNOWPLAY_RESOURCE_ROOT=str(root/'Sources/SnowPlay/Resources')),check=True)
