#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
roll_preview=$(mktemp -d "$PWD/reports/previews/roll-in-app.XXXXXXXX")
roll_app="$roll_preview/小球滚近预览（未安装）.app"
mkdir -p "$roll_app/Contents/MacOS" "$roll_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_ROLL_IN_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift -framework AppKit -framework CoreImage -o "$roll_app/Contents/MacOS/CatRollInPreview"
cp scripts/preview-roll-in-Info.plist "$roll_app/Contents/Info.plist"
cp src/assets/*.png "$roll_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$roll_app/Contents/Resources/"
codesign --force --sign - "$roll_app"
codesign --verify --deep --strict "$roll_app"
print -r -- "$roll_app"
