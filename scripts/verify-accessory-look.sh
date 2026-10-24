#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
look_check=$(mktemp -d /tmp/cat-accessory-look-tests.XXXXXXXX)
trap 'rm -rf "$look_check"' EXIT
swiftc src/macos/CatAccessoryLook.swift scripts/accessory-look-tests.swift -o "$look_check/model"
"$look_check/model"
mkdir -p "$look_check/assets"
cp src/letter.txt "$look_check/letter.txt"
cp src/assets/letter-stationery-v1.png "$look_check/assets/"
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/accessory-look-integration-tests.swift -framework AppKit -framework CoreImage -o "$look_check/integration"
"$look_check/integration"
swiftc -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_LOOK_PREVIEW -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS accessory look preview Intel typecheck (not hardware verification)'
