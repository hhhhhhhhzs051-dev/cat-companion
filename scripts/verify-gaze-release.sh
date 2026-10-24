#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/cat-gaze-release-tests.XXXXXXXX)
trap 'rm -rf "$check_dir"' EXIT
mkdir -p "$check_dir/assets"
cp src/letter.txt "$check_dir/letter.txt"
cp src/assets/letter-stationery-v1.png "$check_dir/assets/"
# Actual release feature flags: no mock rewards, preview persistence, or selectors.
swiftc -D CAT_ACCESSORY_GAZE -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/continuous-gaze-integration-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/integration"
CAT_TEST_COPY_FILE="$check_dir/copy.json" CAT_TEST_GROWTH_FILE="$check_dir/growth.json" "$check_dir/integration" --self-test
swiftc -D CAT_ACCESSORY_GAZE -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
mkdir -p reports/previews
pixel_dir=$(mktemp -d "$PWD/reports/previews/release-gaze-check.XXXXXXXX")
swiftc -O -D CAT_ACCESSORY_GAZE -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatAccessoryGaze,CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  scripts/continuous-gaze-render-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/pixels"
"$check_dir/pixels" "$pixel_dir"
swiftc -O -D CAT_ACCESSORY_GAZE -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatEyeGaze,CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  scripts/fixtures/LegacyNativeCatView.swift scripts/idle-cache-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/idle"
"$check_dir/idle"
print 'PASS release flags, persisted accessories, no preview controls, Intel typecheck and approved eye pixel bounds'
