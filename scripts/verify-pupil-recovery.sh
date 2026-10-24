#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-pupil-recovery.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc $flags src/macos/CatToyPupil.swift scripts/pupil-recovery-tests.swift -o "$out/model"
"$out/model"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/pupil-recovery-integration-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
"$out/integration"
swiftc -O -D CAT_RENDER_TEST $flags src/macos/{CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/pupil-play-render-tests.swift -framework AppKit -framework CoreImage -o "$out/pixels"
"$out/pixels" "$out"
swiftc -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS pupil recovery isolated preview verification'
