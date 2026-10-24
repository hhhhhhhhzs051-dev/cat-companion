#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
roll_tests=$(mktemp -d /tmp/cat-roll-tests.XXXXXXXX)
trap 'rm -rf "$roll_tests"' EXIT
swiftc src/macos/CatToy.swift scripts/fixtures/Build55CatToy.swift scripts/toy-roll-in-tests.swift -o "$roll_tests/model"
"$roll_tests/model"
swiftc -D CAT_PLAY_PREVIEW -D CAT_ROLL_IN_PREVIEW -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/toy-roll-in-integration-tests.swift -framework AppKit -framework CoreImage -o "$roll_tests/integration"
"$roll_tests/integration"
swiftc -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/toy-roll-in-integration-tests.swift -framework AppKit -framework CoreImage -o "$roll_tests/production-integration"
"$roll_tests/production-integration" --self-test
swiftc -D CAT_PLAY_PREVIEW -D CAT_ROLL_IN_PREVIEW -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
print 'PASS roll-in preview Intel typecheck (not hardware verification)'
