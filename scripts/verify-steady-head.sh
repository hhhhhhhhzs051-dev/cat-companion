#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
steady_work=$(mktemp -d /tmp/cat-steady-verification.XXXXXXXX)
trap 'rm -rf "$steady_work"' EXIT
swiftc -D CAT_PAW_EXPERIMENT src/macos/{CatMotion,CatMouth,CatPaw,CatGrooming}.swift scripts/head-steady-tests.swift -o "$steady_work/model"
"$steady_work/model"
# Use the accepted native input/menu assertions unchanged, with the preview's
# model configuration in every fresh instance (not the production defaults).
sed -E -e 's/CatMotion\(([^)]*)\)/CatMotion(\1,refinedTouch:true,headPetLeans:false)/g' -e 's/func runMenuTests\(/func runExistingMenuTests(/' scripts/menu-tests.swift > "$steady_work/menu-tests.swift"
mkdir -p "$steady_work/assets"
cp src/letter.txt "$steady_work/letter.txt"
cp src/assets/letter-stationery-v1.png "$steady_work/assets/"
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_TOUCH_PREVIEW -D CAT_STEADY_HEAD_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift "$steady_work/menu-tests.swift" scripts/head-steady-integration-entry.swift -framework AppKit -framework CoreImage -o "$steady_work/integration"
"$steady_work/integration"
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/head-steady-render-tests.swift -framework AppKit -framework CoreImage -o "$steady_work/render"
"$steady_work/render"
swiftc -D CAT_PLAY_PREVIEW -D CAT_TOUCH_PREVIEW -D CAT_STEADY_HEAD_PREVIEW -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS steady-head preview Intel typecheck (not hardware verification)'
