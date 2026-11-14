#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
.build/toolchain/swiftc -sdk "$(xcrun --show-sdk-path)" -target arm64-apple-macosx13.0 -I .build/debug/Modules Sources/SnowPlay/Resources.swift Sources/SnowPlay/WinterGeometry.swift Sources/SnowPlay/Overlay.swift Sources/SnowPlay/WindowObserver.swift Sources/SnowPlay/DockObserver.swift Sources/SnowPlay/Decorations.swift Sources/SnowPlay/WorldDecorations.swift Sources/SnowPlay/FloorDecorations.swift Sources/SnowPlay/CharacterDecorations.swift Scripts/MotionPreview.swift .build/debug/SnowCore.build/*.o -o .build/motion-preview
SNOWPLAY_RESOURCE_ROOT="$PWD/Sources/SnowPlay/Resources" .build/motion-preview
