#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
closed_preview=$(mktemp -d "$PWD/reports/previews/closed-eye-app.XXXXXXXX")
closed_app="$closed_preview/闭眼复用预览（未安装）.app"
mkdir -p "$closed_app/Contents/MacOS" "$closed_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_CLOSED_EYE_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$closed_app/Contents/MacOS/CatClosedEyePreview"
cp scripts/preview-closed-eye-Info.plist "$closed_app/Contents/Info.plist"
cp src/assets/*.png "$closed_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$closed_app/Contents/Resources/"
codesign --force --sign - "$closed_app"
codesign --verify --deep --strict "$closed_app"
print -r -- "$closed_app"
