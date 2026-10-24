#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
preview_dir=$(mktemp -d "$PWD/reports/previews/continuous-gaze-app.XXXXXXXX")
preview_app="$preview_dir/花鱼连续轻瞥预览（未安装）.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_ACCESSORY_EYE_PREVIEW -D CAT_ACCESSORY_CONTINUOUS_PREVIEW -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift scripts/EyeGazePlayback.swift -framework AppKit -framework CoreImage -o "$preview_app/Contents/MacOS/CatContinuousGazePreview"
cp scripts/preview-continuous-gaze-Info.plist "$preview_app/Contents/Info.plist"
cp src/assets/*.png "$preview_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$preview_app/Contents/Resources/"
codesign --force --sign - "$preview_app"
codesign --verify --deep --strict "$preview_app"
print -r -- "$preview_app"
