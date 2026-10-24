#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
eye_preview=$(mktemp -d "$PWD/reports/previews/eye-study-app.XXXXXXXX")
eye_app="$eye_preview/眼内整体移动预览（未安装）.app"
mkdir -p "$eye_app/Contents/MacOS" "$eye_app/Contents/Resources/assets"
# CAT_EYE_STUDY_APP replaces the real app entry point. Only the standalone study
# creates windows; it never constructs PetApp or any save/settings controller.
swiftc -O -D CAT_EYE_STUDY_APP -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT \
  -target arm64-apple-macos14.0 src/macos/*.swift scripts/preview-eye-gaze.swift \
  -framework AppKit -framework CoreImage -o "$eye_app/Contents/MacOS/CatEyeStudy"
cp scripts/preview-eye-gaze-Info.plist "$eye_app/Contents/Info.plist"
for asset in cat-d.png cat-closed.png bed-complete-v2.png cat-tongue-v1.png cat-paw-contact-v1.png; do
  cp "src/assets/$asset" "$eye_app/Contents/Resources/assets/"
done
codesign --force --sign - "$eye_app"
codesign --verify --deep --strict "$eye_app"
print -r -- "$eye_app"
