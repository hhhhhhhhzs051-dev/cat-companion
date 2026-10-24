#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/cat-eye-release.XXXXXXXX)
print -r -- "$check_dir"
flags=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION)
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-release-storage-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/storage"
"$check_dir/storage"
swiftc $flags src/macos/CatToyPupil.swift src/macos/CatAccessoryGaze.swift scripts/eye-coordination-tests.swift -o "$check_dir/model"
"$check_dir/model"
swiftc $flags src/macos/CatToy.swift scripts/toy-accessory-priority-tests.swift -o "$check_dir/toy"
"$check_dir/toy"
mkdir -p "$check_dir/assets"
cp src/letter.txt "$check_dir/letter.txt"
cp src/assets/letter-stationery-v1.png "$check_dir/assets/"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-interaction-integration-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/integration"
CAT_TEST_COPY_FILE="$check_dir/copy.json" CAT_TEST_GROWTH_FILE="$check_dir/growth.json" "$check_dir/integration" --self-test
swiftc -O -D CAT_RENDER_TEST $flags src/macos/{CatAccessoryGaze,CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/continuous-gaze-render-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/pixels"
"$check_dir/pixels" "$check_dir"
swiftc -O -D CAT_RENDER_TEST $flags src/macos/{CatEyeGaze,CatPupilArt,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/{EyeVariationPlayback,eye-variation-animation-tests}.swift scripts/fixtures/AcceptedStaticEyeVariation.swift -framework AppKit -framework CoreImage -o "$check_dir/pupil-pixels"
"$check_dir/pupil-pixels" "$check_dir"
swiftc -typecheck $flags -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS accepted eye interaction release flags, isolation, persistence, pixels and Intel typecheck'
