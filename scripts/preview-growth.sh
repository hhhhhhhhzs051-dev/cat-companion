#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
preview_work=$(mktemp -d "$PWD/reports/previews/growth.XXXXXXXX")
preview_app="$preview_work/小猫成长预览（未安装）.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_GROWTH_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift -framework AppKit -framework CoreImage -o "$preview_app/Contents/MacOS/CatGrowthPreview"
cp scripts/preview-growth-Info.plist "$preview_app/Contents/Info.plist"
cp src/assets/*.png "$preview_app/Contents/Resources/assets/"
cp src/cat-copy.json src/letter.txt "$preview_app/Contents/Resources/"
codesign --force --sign - "$preview_app"
codesign --verify --deep --strict "$preview_app"
print -r -- "$preview_app"
