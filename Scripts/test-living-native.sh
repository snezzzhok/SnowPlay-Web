#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
Scripts/local-build.sh build
python3 Scripts/compile-regression-checks.py
python3 - <<'PY'
from pathlib import Path
import os,subprocess,tempfile
for check in ['RendererCheck','AssetIntegrationCheck','LivingNativeCheck']:
 with tempfile.TemporaryDirectory(prefix='snowplay-living-test-') as folder:
  subprocess.run(['.build/regression-checks',check,'--config',str(Path(folder)/'settings.json')],check=True,env=dict(os.environ,SNOWPLAY_RESOURCE_ROOT=str(Path.cwd()/'Sources/SnowPlay/Resources')))
PY
