#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
study_dir=$(mktemp -d "$PWD/reports/previews/eye-variation-animation-app.XXXXXXXX")
study_app="$study_dir/瞳孔宽度对照预览（未安装）.app"
mkdir -p "$study_app/Contents/MacOS" "$study_app/Contents/Resources/assets"
swiftc -O -D CAT_EYE_STUDY_APP -D CAT_EYE_VARIATION_STUDY -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT \
  -target arm64-apple-macos14.0 src/macos/*.swift scripts/{EyeVariationPlayback,preview-eye-variation-animation}.swift \
  -framework AppKit -framework CoreImage -o "$study_app/Contents/MacOS/CatEyeVariationAnimation"
cp scripts/preview-eye-variation-animation-Info.plist "$study_app/Contents/Info.plist"
for asset in cat-d.png cat-closed.png bed-complete-v2.png cat-tongue-v1.png cat-paw-contact-v1.png; do
  cp "src/assets/$asset" "$study_app/Contents/Resources/assets/"
done
codesign --force --sign - "$study_app"
codesign --verify --deep --strict "$study_app"
print -r -- "$study_app"
