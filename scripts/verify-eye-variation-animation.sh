#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
animation_check=$(mktemp -d "$PWD/reports/previews/eye-variation-animation-check.XXXXXXXX")
print -r -- "$animation_check"
swiftc -O -D CAT_EYE_VARIATION_STUDY -D CAT_EYE_GAZE_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  src/macos/CatPupilArt.swift scripts/{EyeVariationPlayback,eye-variation-animation-tests}.swift scripts/fixtures/AcceptedStaticEyeVariation.swift \
  -framework AppKit -framework CoreImage -o "$animation_check/check"
"$animation_check/check" "$animation_check" "$@"
