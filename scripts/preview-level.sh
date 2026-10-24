#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
level_work=$(mktemp -d "$PWD/reports/previews/level-feedback.XXXXXXXX")
level_app="$level_work/等级与完成短句预览（未安装）.app"
mkdir -p "$level_app/Contents/MacOS" "$level_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_GROWTH_PREVIEW -D CAT_LEVEL_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift -framework AppKit -framework CoreImage -o "$level_app/Contents/MacOS/CatLevelPreview"
cp scripts/preview-level-Info.plist "$level_app/Contents/Info.plist"
cp src/assets/*.png "$level_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$level_app/Contents/Resources/"
codesign --force --sign - "$level_app"
codesign --verify --deep --strict "$level_app"
print -r -- "$level_app"
