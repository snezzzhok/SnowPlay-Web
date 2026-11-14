#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
.build/toolchain/swiftc -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx13.0 -I .build/debug/Modules Sources/SnowPlay/Resources.swift Sources/SnowPlay/WinterGeometry.swift Sources/SnowPlay/Overlay.swift Sources/SnowPlay/WindowObserver.swift Sources/SnowPlay/DockObserver.swift Scripts/WinterVisualCheck.swift .build/debug/SnowCore.build/*.o -o .build/winter-visual-check
SNOWPLAY_RESOURCE_ROOT="$PWD/Sources/SnowPlay/Resources" .build/winter-visual-check
