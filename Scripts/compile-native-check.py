#!/usr/bin/env python3
"""Compile a fixture against the actual app sources (excluding the app entry point)."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
script=Path(sys.argv[1]);output=Path(sys.argv[2])
mode='release' if '--release' in sys.argv[3:] else 'debug'
files=[str(p) for p in sorted((root/'Sources/SnowPlay').glob('*.swift')) if p.name!='main.swift']
subprocess.run([str(root/'.build/toolchain/swiftc'),'-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-target','arm64-apple-macosx13.0',*(['-O'] if mode=='release' else []),'-I',str(root/f'.build/{mode}/Modules'),*files,str(script),*map(str,(root/f'.build/{mode}/SnowCore.build').glob('*.o')),'-o',str(output)],cwd=root,check=True)
