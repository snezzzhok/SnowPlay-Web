#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${SNOWPLAY_LOCAL_TOOLCHAIN_WORKAROUND:-0}" == 1 ]]; then
  Scripts/local-build.sh build -c release
else
  swift build -c release
fi
python3 Scripts/prepare-assets.py --check
app="$PWD/dist/SnowPlay.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/SnowPlay "$app/Contents/MacOS/SnowPlay"
cp Packaging/Info.plist "$app/Contents/Info.plist"
# SwiftPM Bundle.module locates its generated resource bundle inside Contents/Resources (resolved before Bundle.module fallback).
for bundle in .build/release/SnowPlay_*.bundle; do
  rm -rf "$app/Contents/Resources/$(basename "$bundle")"
  cp -R "$bundle" "$app/Contents/Resources/"
done
codesign --force --sign "${SNOWPLAY_SIGN_IDENTITY:--}" "$app"
codesign --verify --strict "$app"
if [[ -n "${SNOWPLAY_NOTARY_PROFILE:-}" ]]; then
  ditto -c -k --keepParent "$app" dist/SnowPlay-notarize.zip
  xcrun notarytool submit dist/SnowPlay-notarize.zip --keychain-profile "$SNOWPLAY_NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
fi
ditto -c -k --keepParent "$app" dist/SnowPlay-macOS.zip
printf 'Built %s\n' "$app"
