#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-eye-handoff.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_EYE_HANDOFF_PREVIEW -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-handoff-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
"$out/integration"
sources=(src/macos/{CatEyeHandoff,CatAccessoryGaze,CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift)
swiftc -O -D CAT_RENDER_TEST $flags $sources scripts/eye-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/pixels"
"$out/pixels" "$out"
mkdir "$out/baseline"
# Build the accepted renderer branch, without the new preview definition.
swiftc -O -D CAT_RENDER_TEST -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT $sources scripts/eye-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/baseline/pixels"
"$out/baseline/pixels" "$out/baseline"
for name in neutral pupil gaze gaze-half; do cmp "$out/$name.png" "$out/baseline/$name.png"; done
print 'PASS accepted single-effect pixels unchanged'
swiftc -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
