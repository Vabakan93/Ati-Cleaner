#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Ati Cleaner"
BIN_NAME="AtiCleaner"
VOLUME="Ati Cleaner"
DMG_NAME="AtiCleaner.dmg"

echo "Derleniyor…"
swift build -c release

echo "App bundle oluşturuluyor…"
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

echo "DMG hazırlanıyor…"
DMG_ROOT="dist/dmg_root"
rm -rf "$DMG_ROOT" "$DMG_NAME"
mkdir -p "$DMG_ROOT"
cp -R "$BUNDLE" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create -volname "$VOLUME" -srcfolder "$DMG_ROOT" -ov -format UDZO "dist/$DMG_NAME" >/dev/null
rm -rf "$DMG_ROOT"

echo "DMG hazır: dist/$DMG_NAME"
ls -lh "dist/$DMG_NAME" | awk '{print $5, $9}'

echo "iCloud Drive'a kopyalanıyor…"
ICLOUD="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
if [ -d "$ICLOUD" ]; then
    cp "dist/$DMG_NAME" "$ICLOUD/$DMG_NAME"
    echo "iCloud Drive'a kopyalandı: $ICLOUD/$DMG_NAME"
else
    echo "UYARI: iCloud Drive klasörü bulunamadı. DMG dist/ klasöründe duruyor."
fi