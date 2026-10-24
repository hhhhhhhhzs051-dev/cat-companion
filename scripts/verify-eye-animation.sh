#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
eye_check=$(mktemp -d "$PWD/reports/previews/eye-animation-check.XXXXXXXX")
print -r -- "$eye_check"
swiftc -D CAT_EYE_GAZE_PREVIEW src/macos/CatEyeGaze.swift scripts/{EyeGazePlayback,eye-playback-tests}.swift \
  -framework CoreImage -o "$eye_check/playback-check"
"$eye_check/playback-check"
swiftc -O -D CAT_EYE_GAZE_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  scripts/{EyeGazePlayback,EyeAnimationPlayer,eye-animation-tests}.swift \
  scripts/fixtures/StaticRigidEyeGaze.swift \
  -framework AppKit -framework CoreImage -o "$eye_check/check"
"$eye_check/check" "$eye_check"
