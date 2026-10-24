#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
flags=(-D CAT_GRAB_HANDOFF_PREVIEW -D CAT_EYE_HANDOFF_PREVIEW -D CAT_PUPIL_RECOVERY_PREVIEW -D CAT_PUPIL_PLAY_PREVIEW -D CAT_PLAY_PREVIEW -D CAT_ACCESSORY_PREVIEW -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION_PREVIEW -D CAT_EYE_VARIATION_STUDY -D CAT_PAW_EXPERIMENT)
swiftc -suppress-warnings -O -D CAT_MENU_TEST $flags src/macos/*.swift scripts/background-eye-tests.swift -framework AppKit -framework CoreImage -o "$work/background-tests"
"$work/background-tests"
# Exercise the exact formal compile definitions with explicit temporary saves.
release=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY -D CAT_PUPIL_RECOVERY -D CAT_EYE_HANDOFF -D CAT_GRAB_HANDOFF)
swiftc -suppress-warnings -O -D CAT_MENU_TEST $release src/macos/*.swift scripts/background-eye-tests.swift -framework AppKit -framework CoreImage -o "$work/background-release-tests"
CAT_TEST_COPY_FILE="$work/copy.json" CAT_TEST_GROWTH_FILE="$work/growth.json" "$work/background-release-tests" --self-test
