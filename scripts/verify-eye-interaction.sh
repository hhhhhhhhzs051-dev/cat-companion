#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
check_dir=$(mktemp -d "$PWD/reports/previews/eye-interaction-check.XXXXXXXX")
print -r -- "$check_dir"
flags=(-D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc $flags src/macos/CatToyPupil.swift scripts/toy-pupil-tests.swift -o "$check_dir/model"
"$check_dir/model"
swiftc $flags src/macos/CatToyPupil.swift src/macos/CatAccessoryGaze.swift scripts/eye-coordination-tests.swift -o "$check_dir/coordination"
"$check_dir/coordination"
swiftc $flags src/macos/CatToy.swift scripts/toy-accessory-priority-tests.swift -o "$check_dir/toy-priority"
"$check_dir/toy-priority"
mkdir -p "$check_dir/assets"
cp src/letter.txt "$check_dir/letter.txt"
cp src/assets/letter-stationery-v1.png "$check_dir/assets/"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/eye-interaction-integration-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/integration"
"$check_dir/integration"
