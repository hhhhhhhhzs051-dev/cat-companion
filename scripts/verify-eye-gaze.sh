#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
eye_check=$(mktemp -d "$PWD/reports/previews/eye-gaze-check.XXXXXXXX")
cat scripts/fixtures/Build61NativeCatSource.swift |
  sed -e 's/NativeCatView/Build61NativeCatView/g' -e 's/CatIdleFrameCache/Build61IdleFrameCache/g' > "$eye_check/Build61NativeCatView.swift"
swiftc -O -D CAT_EYE_GAZE_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  "$eye_check/Build61NativeCatView.swift" scripts/eye-gaze-tests.swift \
  -framework AppKit -framework CoreImage -o "$eye_check/check"
print -r -- "$eye_check"
"$eye_check/check" "$eye_check"
