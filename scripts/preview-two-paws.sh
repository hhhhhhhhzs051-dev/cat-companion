#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
preview_parent="${CAT_PREVIEW_DIR:-$PWD/reports/previews}"
mkdir -p "$preview_parent"
preview_work=$(mktemp -d "$preview_parent/two-paws.XXXXXXXX")
preview_app="$preview_work/左右爪预览.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources/assets"
swiftc -O -D CAT_MENU_TEST -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/preview-two-paws.swift -framework AppKit -framework CoreImage -o "$preview_app/Contents/MacOS/CatTwoPawPreview"
cp scripts/preview-two-paws-Info.plist "$preview_app/Contents/Info.plist"
cp scripts/preview-two-paws-launcher.sh "$preview_app/Contents/MacOS/preview-launcher"
chmod +x "$preview_app/Contents/MacOS/preview-launcher"
cp src/assets/*.png "$preview_app/Contents/Resources/assets/"
cp src/cat-copy.json src/letter.txt "$preview_app/Contents/Resources/"
codesign --force --sign - "$preview_app/Contents/MacOS/CatTwoPawPreview"
codesign --force --sign - "$preview_app"
codesign --verify --deep --strict "$preview_app"
print -r -- "Preview only, formal app untouched: $preview_app"
