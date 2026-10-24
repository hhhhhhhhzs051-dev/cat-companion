#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
out=$(mktemp -d "$PWD/reports/previews/pupil-play-pixels.XXXXXXXX")
print -r -- "$out"
flags=(-D CAT_PUPIL_PLAY_PREVIEW -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_ACCESSORY_GAZE -D CAT_PAW_EXPERIMENT -D CAT_RENDER_TEST)
swiftc -O $flags src/macos/{CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/pupil-play-render-tests.swift -framework AppKit -framework CoreImage -o "$out/check"
"$out/check" "$out"
