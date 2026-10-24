#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
look_preview=$(mktemp -d "$PWD/reports/previews/accessory-look-app.XXXXXXXX")
look_app="$look_preview/饰品轻瞥预览（未安装）.app"
mkdir -p "$look_app/Contents/MacOS" "$look_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$look_app/Contents/MacOS/CatAccessoryLookPreview"
cp scripts/preview-accessory-look-Info.plist "$look_app/Contents/Info.plist"
cp src/assets/*.png "$look_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$look_app/Contents/Resources/"
codesign --force --sign - "$look_app"
codesign --verify --deep --strict "$look_app"
print -r -- "$look_app"
