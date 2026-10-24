#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
completion_work=$(mktemp -d "$PWD/reports/previews/completion-delivery.XXXXXXXX")
completion_app="$completion_work/摸猫短句预览（未安装）.app"
mkdir -p "$completion_app/Contents/MacOS" "$completion_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_GROWTH_PREVIEW -D CAT_LEVEL_PREVIEW -D CAT_COMPLETION_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift -framework AppKit -framework CoreImage -o "$completion_app/Contents/MacOS/CatCompletionPreview"
cp scripts/preview-completion-Info.plist "$completion_app/Contents/Info.plist"
cp src/assets/*.png "$completion_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$completion_app/Contents/Resources/"
codesign --force --sign - "$completion_app"
codesign --verify --deep --strict "$completion_app"
print -r -- "$completion_app"
