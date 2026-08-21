#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Ati Cleaner"
BIN_NAME="AtiCleaner"

echo "Derleniyor…"
swift build -c release

BUNDLE="dist/$APP_NAME.app"
BIN="$BUNDLE/Contents/MacOS"
RES="$BUNDLE/Contents/Resources"

rm -rf "$BUNDLE"
mkdir -p "$BIN" "$RES"

cp .build/release/MacCleaner "$BIN/$BIN_NAME"
cp Scripts/Info.plist "$BUNDLE/Contents/Info.plist"
cp Scripts/AppIcon.icns "$RES/AppIcon.icns"

IDENTITY="Ati Cleaner Developer"
if codesign --force --sign "$IDENTITY" "$BUNDLE" 2>/dev/null; then
    echo "İmza: $IDENTITY"
else
    codesign --force --sign - "$BUNDLE" 2>/dev/null || true
    echo "İmza: ad-hoc"
fi

echo "Uygulama hazır: $BUNDLE"
echo "Uygulamalar klasörüne kopyalanıyor…"
rm -rf "/Applications/$APP_NAME.app"
cp -R "$BUNDLE" "/Applications/$APP_NAME.app"

echo "Başlatılıyor…"
open "/Applications/$APP_NAME.app"