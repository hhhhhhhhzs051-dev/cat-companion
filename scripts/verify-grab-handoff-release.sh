#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-grab-release.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY -D CAT_PUPIL_RECOVERY -D CAT_EYE_HANDOFF -D CAT_GRAB_HANDOFF)
swiftc -O $flags src/macos/CatAccessoryGaze.swift scripts/grab-handoff-tests.swift -o "$out/model"
"$out/model"
swiftc -suppress-warnings -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/grab-handoff-integration-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
CAT_TEST_COPY_FILE="$out/copy.json" CAT_TEST_GROWTH_FILE="$out/growth.json" "$out/integration" --self-test
swiftc -suppress-warnings -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-release-storage-tests.swift -framework AppKit -framework CoreImage -o "$out/storage"
"$out/storage"
sources=(src/macos/{CatEyeHandoff,CatAccessoryGaze,CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift)
mkdir "$out/formal" "$out/preview"
swiftc -O -D CAT_RENDER_TEST $flags $sources scripts/grab-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/formal/pixels"
"$out/formal/pixels" "$out/formal"
preview=(-D CAT_GRAB_HANDOFF_PREVIEW -D CAT_EYE_HANDOFF_PREVIEW -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc -O -D CAT_RENDER_TEST $preview $sources scripts/grab-handoff-render-tests.swift -framework AppKit -framework CoreImage -o "$out/preview/pixels"
"$out/preview/pixels" "$out/preview"
for frame in "$out/formal"/*.rgba; do cmp "$frame" "$out/preview/${frame:t}"; done
swiftc -suppress-warnings -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS formal grab handoff, storage isolation/reopening, 66 preview frames pixel-exact and Intel typecheck'
