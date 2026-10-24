#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
accessory_preview=$(mktemp -d "$PWD/reports/previews/accessory-pair-app.XXXXXXXX")
accessory_app="$accessory_preview/花鱼同摆预览（未安装）.app"
mkdir -p "$accessory_app/Contents/MacOS" "$accessory_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$accessory_app/Contents/MacOS/CatAccessoryPairPreview"
cp scripts/preview-accessory-Info.plist "$accessory_app/Contents/Info.plist"
cp src/assets/*.png "$accessory_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$accessory_app/Contents/Resources/"
codesign --force --sign - "$accessory_app"
codesign --verify --deep --strict "$accessory_app"
print -r -- "$accessory_app"
