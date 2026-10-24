#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-eye-handoff-release.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY -D CAT_PUPIL_RECOVERY -D CAT_EYE_HANDOFF)
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-handoff-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
CAT_TEST_COPY_FILE="$out/copy.json" CAT_TEST_GROWTH_FILE="$out/growth.json" "$out/integration" --self-test
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-release-storage-tests.swift -framework AppKit -framework CoreImage -o "$out/storage"
"$out/storage"
sources=(src/macos/{CatEyeHandoff,CatAccessoryGaze,CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift)
swiftc -O -D CAT_RENDER_TEST $flags $sources scripts/eye-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/pixels"
"$out/pixels" "$out"
mkdir "$out/preview" "$out/baseline"
preview=(-D CAT_EYE_HANDOFF_PREVIEW -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc -O -D CAT_RENDER_TEST $preview $sources scripts/eye-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/preview/pixels"
"$out/preview/pixels" "$out/preview"
for frame in "$out"/*.png; do cmp "$frame" "$out/preview/${frame:t}"; done
swiftc -O -D CAT_RENDER_TEST -D CAT_PUPIL_RECOVERY -D CAT_PUPIL_PLAY -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PAW_EXPERIMENT $sources scripts/eye-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/baseline/pixels"
"$out/baseline/pixels" "$out/baseline"
for name in neutral pupil gaze gaze-half; do cmp "$out/$name.png" "$out/baseline/$name.png"; done
swiftc -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS formal handoff events, isolated save reopening, accepted preview pixels exact, build65 single-effect pixels exact and Intel typecheck'
