#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="dist/Ati Cleaner.app"
OUT="dist/AtiCleaner.dmg"
[[ -d "$APP" ]] || { echo "Build the app first: ./Scripts/build-app.sh"; exit 1; }
rm -f "$OUT"
hdiutil create -volname "Ati Cleaner" -srcfolder "$APP" -ov -format UDZO "$OUT"
echo "Created: $OUT"
