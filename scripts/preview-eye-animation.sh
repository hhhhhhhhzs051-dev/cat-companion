#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
eye_preview=$(mktemp -d "$PWD/reports/previews/eye-animation-app.XXXXXXXX")
eye_app="$eye_preview/眼神轻移动画预览（未安装）.app"
mkdir -p "$eye_app/Contents/MacOS" "$eye_app/Contents/Resources/assets"
swiftc -O -D CAT_EYE_STUDY_APP -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT \
  -target arm64-apple-macos14.0 src/macos/*.swift \
  scripts/{EyeGazePlayback,EyeAnimationPlayer,preview-eye-animation}.swift \
  -framework AppKit -framework CoreImage -o "$eye_app/Contents/MacOS/CatEyeAnimation"
cp scripts/preview-eye-animation-Info.plist "$eye_app/Contents/Info.plist"
for asset in cat-d.png cat-closed.png bed-complete-v2.png cat-tongue-v1.png cat-paw-contact-v1.png; do
  cp "src/assets/$asset" "$eye_app/Contents/Resources/assets/"
done
codesign --force --sign - "$eye_app"
codesign --verify --deep --strict "$eye_app"
print -r -- "$eye_app"
