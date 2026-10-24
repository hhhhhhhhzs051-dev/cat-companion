#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
steady_preview=$(mktemp -d "$PWD/reports/previews/steady-head-app.XXXXXXXX")
steady_app="$steady_preview/摸头稳身预览（未安装）.app"
mkdir -p "$steady_app/Contents/MacOS" "$steady_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_TOUCH_PREVIEW -D CAT_STEADY_HEAD_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$steady_app/Contents/MacOS/CatSteadyHeadPreview"
cp scripts/preview-steady-head-Info.plist "$steady_app/Contents/Info.plist"
cp src/assets/*.png "$steady_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$steady_app/Contents/Resources/"
codesign --force --sign - "$steady_app"
codesign --verify --deep --strict "$steady_app"
print -r -- "$steady_app"
