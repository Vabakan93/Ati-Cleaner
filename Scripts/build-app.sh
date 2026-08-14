#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="Ati Cleaner"
EXECUTABLE="AtiCleaner"
BUNDLE="$ROOT/dist/$APP_NAME.app"
CONTENTS="$BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

swift build -c release
rm -rf "$BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"
cp ".build/release/$EXECUTABLE" "$MACOS/$EXECUTABLE"
cp "Scripts/Info.plist" "$CONTENTS/Info.plist"

if [[ -f "Assets/AppIcon.icns" ]]; then
  cp "Assets/AppIcon.icns" "$RESOURCES/AppIcon.icns"
elif [[ -f "Assets/AppIcon.png" ]]; then
  echo "Generating AppIcon.icns from Assets/AppIcon.png..."
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for spec in "16 icon_16x16.png" "32 icon_16x16@2x.png" "32 icon_32x32.png" "64 icon_32x32@2x.png" "128 icon_128x128.png" "256 icon_128x128@2x.png" "256 icon_256x256.png" "512 icon_256x256@2x.png" "512 icon_512x512.png" "1024 icon_512x512@2x.png"; do
    set -- $spec
    sips -z "$1" "$1" "Assets/AppIcon.png" --out "$ICONSET/$2" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
  cp "$RESOURCES/AppIcon.icns" "Assets/AppIcon.icns"
  rm -rf "$(dirname "$ICONSET")"
else
  echo "Warning: No AppIcon.icns or AppIcon.png found; app will use default icon."
fi

IDENTITY="${ATI_CODESIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$IDENTITY" "$BUNDLE"
  echo "Signed with: $IDENTITY"
else
  codesign --force --deep --sign - "$BUNDLE" >/dev/null 2>&1 || true
  echo "Signed ad-hoc for local testing."
fi

echo "Built: $BUNDLE"
