#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
accessory_work=$(mktemp -d /tmp/cat-accessory-check.XXXXXXXX)
trap 'rm -rf "$accessory_work"' EXIT
swiftc src/macos/CatAccessorySway.swift scripts/accessory-sway-tests.swift -o "$accessory_work/model"
"$accessory_work/model"
sed -E -e 's/CatMotion\(([^)]*)\)/CatMotion(\1,refinedTouch:true,headPetLeans:false)/g' -e 's/func runMenuTests\(/func runExistingMenuTests(/' scripts/menu-tests.swift > "$accessory_work/menu-tests.swift"
mkdir -p "$accessory_work/assets"
cp src/letter.txt "$accessory_work/letter.txt"
cp src/assets/letter-stationery-v1.png "$accessory_work/assets/"
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift "$accessory_work/menu-tests.swift" scripts/fixtures/Build58AccessoryView.swift scripts/fixtures/PairPreviewPeachArt.swift scripts/fixtures/PairPreviewGoldfishArt.swift scripts/accessory-palette-tests.swift scripts/accessory-integration-tests.swift -framework AppKit -framework CoreImage -o "$accessory_work/integration"
"$accessory_work/integration"
swiftc -D CAT_MENU_TEST -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/fixtures/AcceptedPairView.swift scripts/accessory-legacy-render-tests.swift -framework AppKit -framework CoreImage -o "$accessory_work/legacy-render"
"$accessory_work/legacy-render"
swiftc -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS accessory preview Intel typecheck (not hardware verification)'
