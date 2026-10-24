#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out=$(mktemp -d /tmp/cat-pupil-release.XXXXXXXX)
print -r -- "$out"
flags=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY)
swiftc $flags src/macos/CatToyPupil.swift scripts/toy-pupil-play-tests.swift -o "$out/model"
"$out/model"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-release-storage-tests.swift -framework AppKit -framework CoreImage -o "$out/storage"
"$out/storage"
mkdir -p "$out/assets"
cp src/letter.txt "$out/letter.txt"
cp src/assets/letter-stationery-v1.png "$out/assets/"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/pupil-play-integration-tests.swift -framework AppKit -framework CoreImage -o "$out/integration"
CAT_TEST_COPY_FILE="$out/copy.json" CAT_TEST_GROWTH_FILE="$out/growth.json" "$out/integration" --self-test
swiftc -O -D CAT_RENDER_TEST $flags src/macos/{CatToyPupil,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/pupil-play-render-tests.swift -framework AppKit -framework CoreImage -o "$out/pixels"
"$out/pixels" "$out"
swiftc -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS pupil50 release flags, isolated save reopening, normal routing, real handlers, pixels and Intel typecheck'
