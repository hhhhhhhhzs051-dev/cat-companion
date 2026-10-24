#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
eye_check=$(mktemp -d /tmp/cat-accessory-eye-tests.XXXXXXXX)
trap 'rm -rf "$eye_check"' EXIT
mkdir -p "$eye_check/assets"
cp src/letter.txt "$eye_check/letter.txt"
cp src/assets/letter-stationery-v1.png "$eye_check/assets/"
flags=(-D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_ACCESSORY_EYE_PREVIEW -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT)
swiftc -D CAT_MENU_TEST $flags src/macos/*.swift scripts/EyeGazePlayback.swift scripts/accessory-eye-integration-tests.swift -framework AppKit -framework CoreImage -o "$eye_check/integration"
"$eye_check/integration"
mkdir -p reports/previews
eye_pixels=$(mktemp -d "$PWD/reports/previews/accessory-eye-check.XXXXXXXX")
print -r -- "$eye_pixels"
swiftc -O -D CAT_EYE_GAZE_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatEyeGaze,CatAccessoryLook,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  scripts/EyeGazePlayback.swift scripts/accessory-eye-render-tests.swift -framework AppKit -framework CoreImage -o "$eye_check/pixels"
"$eye_check/pixels" "$eye_pixels"
swiftc $flags -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift scripts/EyeGazePlayback.swift
print 'PASS accessory eye preview Intel typecheck (not hardware verification)'
