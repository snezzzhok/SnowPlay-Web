#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 Scripts/compile-native-check.py Scripts/AssetIntegrationCheck.swift .build/asset-check
SNOWPLAY_RESOURCE_ROOT="$PWD/Sources/SnowPlay/Resources" .build/asset-check
