#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
touch_preview=$(mktemp -d "$PWD/reports/previews/touch-response-app.XXXXXXXX")
touch_app="$touch_preview/抚摸回应预览（未安装）.app"
mkdir -p "$touch_app/Contents/MacOS" "$touch_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_TOUCH_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$touch_app/Contents/MacOS/CatTouchPreview"
cp scripts/preview-touch-response-Info.plist "$touch_app/Contents/Info.plist"
cp src/assets/*.png "$touch_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$touch_app/Contents/Resources/"
codesign --force --sign - "$touch_app"
codesign --verify --deep --strict "$touch_app"
print -r -- "$touch_app"
