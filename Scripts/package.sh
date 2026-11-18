#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# One download for both Apple Silicon and Intel Macs.
if [[ "${SNOWPLAY_LOCAL_TOOLCHAIN_WORKAROUND:-0}" == 1 ]]; then
  build=(Scripts/local-build.sh)
else
  build=(swift)
fi
# Build each slice separately. This also supports Command Line Tools installations.
for arch in arm64 x86_64; do
  "${build[@]}" build -c release --triple "$arch-apple-macosx13.0" --scratch-path ".build/package-$arch"
done
arm_bin="$("${build[@]}" build -c release --triple arm64-apple-macosx13.0 --scratch-path .build/package-arm64 --show-bin-path)"
intel_bin="$("${build[@]}" build -c release --triple x86_64-apple-macosx13.0 --scratch-path .build/package-x86_64 --show-bin-path)"

# Stage a fresh bundle so removed resources cannot leak into a new release.
mkdir -p dist
stage="$(mktemp -d "$PWD/dist/.package.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
app="$stage/SnowPlay.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create "$arm_bin/SnowPlay" "$intel_bin/SnowPlay" -output "$app/Contents/MacOS/SnowPlay"
cp Packaging/Info.plist "$app/Contents/Info.plist"
for bundle in "$arm_bin"/SnowPlay_*.bundle; do
  cp -R "$bundle" "$app/Contents/Resources/"
done

identity="${SNOWPLAY_SIGN_IDENTITY:--}"
if [[ -n "${SNOWPLAY_NOTARY_PROFILE:-}" && "$identity" == - ]]; then
  echo "Notarization requires SNOWPLAY_SIGN_IDENTITY with a Developer ID Application certificate." >&2
  exit 1
fi
sign_options=(--force --sign "$identity")
if [[ "$identity" != - ]]; then
  sign_options+=(--options runtime --timestamp)
fi
codesign "${sign_options[@]}" "$app"
codesign --verify --strict "$app"
lipo "$app/Contents/MacOS/SnowPlay" -verify_arch arm64 x86_64
if [[ -n "${SNOWPLAY_NOTARY_PROFILE:-}" ]]; then
  ditto -c -k --keepParent "$app" "$stage/notarize.zip"
  xcrun notarytool submit "$stage/notarize.zip" --keychain-profile "$SNOWPLAY_NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
fi
ditto -c -k --keepParent "$app" "$stage/SnowPlay-macOS.zip"
(cd "$stage" && shasum -a 256 SnowPlay-macOS.zip > SHA256SUMS.txt)
python3 Scripts/check-package.py "$stage/SnowPlay-macOS.zip"
rm -rf dist/SnowPlay.app
mv "$app" dist/SnowPlay.app
mv "$stage/SnowPlay-macOS.zip" "$stage/SHA256SUMS.txt" dist/
printf 'Built %s\n' "$PWD/dist/SnowPlay.app"
