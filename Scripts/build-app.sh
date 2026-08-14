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
  echo "Note: Assets/AppIcon.png found, but AppIcon.icns is preferred for distribution."
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
