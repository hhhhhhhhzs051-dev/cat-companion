#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-grab-handoff.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_GRAB_HANDOFF_PREVIEW -D CAT_EYE_HANDOFF_PREVIEW -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc -O $flags src/macos/CatAccessoryGaze.swift scripts/grab-handoff-tests.swift -o "$out/model"
"$out/model"
swiftc -suppress-warnings -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/grab-handoff-integration-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
"$out/integration"
swiftc src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/letter-font-tests.swift -framework AppKit -o "$out/fonts"
"$out/fonts"
sources=(src/macos/{CatEyeHandoff,CatAccessoryGaze,CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift)
swiftc -O -D CAT_RENDER_TEST $flags $sources scripts/grab-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/pixels"
"$out/pixels"
swiftc -suppress-warnings -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
