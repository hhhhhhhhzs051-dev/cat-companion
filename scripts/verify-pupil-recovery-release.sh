#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-pupil-recovery-release.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY -D CAT_PUPIL_RECOVERY)
swiftc $flags src/macos/CatToyPupil.swift scripts/pupil-recovery-tests.swift -o "$out/model"
"$out/model"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-release-storage-tests.swift -framework AppKit -framework CoreImage -o "$out/storage"
"$out/storage"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/pupil-recovery-integration-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
CAT_TEST_COPY_FILE="$out/copy.json" CAT_TEST_GROWTH_FILE="$out/growth.json" "$out/integration" --self-test
swiftc -O -D CAT_RENDER_TEST $flags src/macos/{CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/pupil-play-render-tests.swift -framework AppKit -framework CoreImage -o "$out/pixels"
"$out/pixels" "$out"
swiftc -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS pupil recovery formal flags, paths, isolated saves, actual events, pixels and Intel typecheck'
