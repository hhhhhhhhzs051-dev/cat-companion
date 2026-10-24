#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
eye_preview=$(mktemp -d "$PWD/reports/previews/accessory-eye-app.XXXXXXXX")
eye_app="$eye_preview/花鱼眼神预览（未安装）.app"
mkdir -p "$eye_app/Contents/MacOS" "$eye_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_ACCESSORY_EYE_PREVIEW -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift scripts/EyeGazePlayback.swift -framework AppKit -framework CoreImage -o "$eye_app/Contents/MacOS/CatAccessoryEyePreview"
cp scripts/preview-accessory-eye-Info.plist "$eye_app/Contents/Info.plist"
cp src/assets/*.png "$eye_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$eye_app/Contents/Resources/"
codesign --force --sign - "$eye_app"
codesign --verify --deep --strict "$eye_app"
print -r -- "$eye_app"
