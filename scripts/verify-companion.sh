#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
companion_check=$(mktemp -d /tmp/cat-companion-tests.XXXXXXXX)
trap 'rm -rf "$companion_check"' EXIT
swiftc src/macos/{CatGrowth,CatGrowthStore,CatLevel,CatPlayMood}.swift scripts/companion-progress-tests.swift -o "$companion_check/model"
"$companion_check/model"
swiftc -D CAT_MENU_TEST -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/companion-growth-tests.swift -framework AppKit -framework CoreImage -o "$companion_check/controller"
"$companion_check/controller"
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_COMPANION_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/companion-preview-tests.swift -framework AppKit -framework CoreImage -o "$companion_check/preview"
"$companion_check/preview"
swiftc -D CAT_PLAY_PREVIEW -D CAT_COMPANION_PREVIEW -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS companion preview Intel typecheck (not hardware verification)'
