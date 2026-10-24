#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
preview_dir=$(mktemp -d "$PWD/reports/previews/eye-handoff-app.XXXXXXXX")
preview_app="$preview_dir/扩瞳与花鱼衔接预览（未安装）.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources/assets"
swiftc -O -D CAT_EYE_HANDOFF_PREVIEW -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$preview_app/Contents/MacOS/CatEyeHandoffPreview"
cp scripts/preview-eye-handoff-Info.plist "$preview_app/Contents/Info.plist"
cp src/assets/*.png "$preview_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$preview_app/Contents/Resources/"
codesign --force --sign - "$preview_app"
codesign --verify --deep --strict "$preview_app"
print -r -- "$preview_app"
