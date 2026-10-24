#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
pixel_dir=$(mktemp -d "$PWD/reports/previews/eye-interaction-pixels.XXXXXXXX")
print -r -- "$pixel_dir"
swiftc -O -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatAccessoryGaze,CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  src/macos/CatPupilArt.swift scripts/continuous-gaze-render-tests.swift -framework AppKit -framework CoreImage -o "$pixel_dir/check"
"$pixel_dir/check" "$pixel_dir"
swiftc -typecheck -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT -target x86_64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage
