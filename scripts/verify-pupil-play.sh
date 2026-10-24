#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d /tmp/cat-pupil-play.XXXXXXXX)
print -r -- "$check_dir"
flags=(-D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT -D CAT_PUPIL_PLAY_PREVIEW)
swiftc $flags src/macos/CatToyPupil.swift scripts/toy-pupil-play-tests.swift -o "$check_dir/model"
"$check_dir/model"
mkdir -p "$check_dir/assets"
cp src/letter.txt "$check_dir/letter.txt"
cp src/assets/letter-stationery-v1.png "$check_dir/assets/"
swiftc -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/pupil-play-integration-tests.swift -framework AppKit -framework CoreImage -o "$check_dir/integration"
"$check_dir/integration"
