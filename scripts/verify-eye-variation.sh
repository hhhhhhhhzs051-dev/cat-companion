#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
eye_check=$(mktemp -d "$PWD/reports/previews/eye-variation-check.XXXXXXXX")
swiftc -O -D CAT_EYE_VARIATION_STUDY -D CAT_EYE_GAZE_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  src/macos/CatPupilArt.swift scripts/eye-variation-tests.swift \
  -framework AppKit -framework CoreImage -o "$eye_check/check"
print -r -- "$eye_check"
"$eye_check/check" "$eye_check"
