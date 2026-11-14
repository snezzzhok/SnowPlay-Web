#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
from pathlib import Path
import subprocess
files=[str(p) for p in sorted(Path('Sources/SnowPlay').glob('*.swift')) if p.name!='main.swift']
subprocess.run(['.build/toolchain/swiftc','-sdk',subprocess.check_output(['xcrun','--show-sdk-path'],text=True).strip(),'-target','arm64-apple-macosx13.0','-I','.build/debug/Modules',*files,'Scripts/WorldIntegrationCheck.swift',*map(str,Path('.build/debug/SnowCore.build').glob('*.o')),'-o','.build/world-native-check'],check=True)
PY
folder=$(mktemp -d -t snowplay-world)
trap 'rm -rf "$folder"' EXIT
SNOWPLAY_RESOURCE_ROOT="$PWD/Sources/SnowPlay/Resources" .build/world-native-check --config "$folder/settings.json"
