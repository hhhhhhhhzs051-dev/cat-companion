#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
touch_release=$(mktemp -d /tmp/cat-touch-release.XXXXXXXX)
trap 'rm -rf "$touch_release"' EXIT
# Exercise production initialization, then the existing native assertions with
# the accepted model in every fresh scenario. Self-test and preview storage are
# isolated separately: self-test deliberately overrides window visibility.
sed -E -e 's/CatMotion\(([^)]*)\)/CatMotion(\1,refinedTouch:true,headPetLeans:false)/g' -e 's/func runMenuTests\(/func runExistingMenuTests(/' scripts/menu-tests.swift > "$touch_release/menu-tests.swift"
mkdir -p "$touch_release/assets"
cp src/letter.txt "$touch_release/letter.txt"
cp src/assets/letter-stationery-v1.png "$touch_release/assets/"
swiftc -D CAT_MENU_TEST -D CAT_PAW_EXPERIMENT src/macos/*.swift "$touch_release/menu-tests.swift" scripts/head-steady-integration-entry.swift -framework AppKit -framework CoreImage -o "$touch_release/integration"
"$touch_release/integration" --self-test
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift "$touch_release/menu-tests.swift" scripts/head-steady-integration-entry.swift -framework AppKit -framework CoreImage -o "$touch_release/native"
"$touch_release/native"
