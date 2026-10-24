#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
preview_parent="${CAT_PREVIEW_DIR:-$PWD/reports/previews}"
mkdir -p "$preview_parent"
preview_work=$(mktemp -d "$preview_parent/original-paw-static.XXXXXXXX")
preview_app="$preview_work/原版爪形静态预览（未安装）.app"
mkdir -p "$preview_app/Contents/MacOS" "$preview_app/Contents/Resources/assets"
swiftc -O -D CAT_PAW_EXPERIMENT \
  src/macos/CatToy.swift src/macos/NativeCat.swift src/macos/CatMotion.swift \
  src/macos/CatDeformation.swift src/macos/CatMouth.swift src/macos/CatMouthArt.swift \
  src/macos/CatPaw.swift src/macos/CatPawArt.swift src/macos/CatPawRig.swift \
  src/macos/CatGrooming.swift scripts/fixtures/PreOuterCatToy.swift \
  scripts/preview-original-paw-poses.swift -framework AppKit -framework CoreImage \
  -o "$preview_app/Contents/MacOS/OriginalPawStaticPreview"
cp scripts/preview-original-paw-poses-Info.plist "$preview_app/Contents/Info.plist"
for asset in cat-d.png cat-closed.png bed-complete-v2.png cat-tongue-v1.png cat-paw-contact-v1.png; do
  cp "src/assets/$asset" "$preview_app/Contents/Resources/assets/"
done
codesign --force --sign - "$preview_app"
codesign --verify --deep --strict "$preview_app"
print -r -- "$preview_app"
