#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/cat-continuous-gaze-tests.XXXXXXXX)
trap 'rm -rf "$check_dir"' EXIT
flags=(-D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_ACCESSORY_EYE_PREVIEW -D CAT_ACCESSORY_CONTINUOUS_PREVIEW -D CAT_EYE_GAZE_PREVIEW -D CAT_PAW_EXPERIMENT)
swiftc $flags src/macos/{CatAccessoryGaze,CatAccessoryLook,CatEyeGaze}.swift scripts/{EyeGazePlayback,continuous-gaze-tests}.swift -framework CoreImage -o "$check_dir/model"
"$check_dir/model"
mkdir -p "$check_dir/assets"
cp src/letter.txt "$check_dir/letter.txt"
cp src/assets/letter-stationery-v1.png "$check_dir/assets/"
swiftc -D CAT_MENU_TEST $flags src/macos/*.swift scripts/EyeGazePlayback.swift scripts/continuous-gaze-integration-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/integration"
"$check_dir/integration"
mkdir -p reports/previews
pixel_dir=$(mktemp -d "$PWD/reports/previews/continuous-gaze-check.XXXXXXXX")
print -r -- "$pixel_dir"
swiftc -O -D CAT_ACCESSORY_CONTINUOUS_PREVIEW -D CAT_EYE_GAZE_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatAccessoryGaze,CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  scripts/continuous-gaze-render-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/pixels"
"$check_dir/pixels" "$pixel_dir"
swiftc $flags -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift scripts/EyeGazePlayback.swift
print 'PASS continuous gaze Intel typecheck (not hardware verification)'
