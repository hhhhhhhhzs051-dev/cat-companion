#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
companion_work=$(mktemp -d "$PWD/reports/previews/companion-app.XXXXXXXX")
companion_app="$companion_work/长期成长预览（未安装）.app"
mkdir -p "$companion_app/Contents/MacOS" "$companion_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_COMPANION_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$companion_app/Contents/MacOS/CatCompanionPreview"
cp scripts/preview-companion-Info.plist "$companion_app/Contents/Info.plist"
cp src/assets/*.png "$companion_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$companion_app/Contents/Resources/"
codesign --force --sign - "$companion_app"
codesign --verify --deep --strict "$companion_app"
print -r -- "$companion_app"
