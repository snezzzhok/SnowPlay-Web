#!/usr/bin/env python3
"""Compile native fixtures together once, preserving their actual app-source dependencies."""
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
names=['AssetIntegrationCheck','RendererCheck','LivingNativeCheck','InteractionCheck','LivingWorkBenchmark']
text='\n'.join((root/f'Scripts/{name}.swift').read_text().replace('@main struct','struct') for name in names)
text+='\n@main struct RegressionChecks {static func main() throws {switch CommandLine.arguments[1] {'
text+=''.join(f'case "{name}":try {name}.main();' for name in names)
text+='default:fatalError("Unknown fixture")}}}\n'
path=root/'.build/RegressionChecks.swift';path.write_text(text)
subprocess.run(['python3',str(root/'Scripts/compile-native-check.py'),str(path),str(root/'.build/regression-checks')],cwd=root,check=True)
