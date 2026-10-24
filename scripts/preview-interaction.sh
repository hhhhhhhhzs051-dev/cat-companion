#!/bin/zsh
# Compile a standalone self-test executable, never a second .app / Bundle ID.
set -euo pipefail
cd "$(dirname "$0")/.."
scratch=$(mktemp -d /tmp/cat-interaction.XXXXXX)
trap 'rm -f "$scratch/CatInteractionCheck"; rmdir "$scratch"' EXIT
swiftc -D CAT_PAW_EXPERIMENT src/macos/*.swift -framework AppKit -framework CoreImage -O -o "$scratch/CatInteractionCheck"
CAT_TEST_RESOURCES="$PWD/src" CAT_TEST_COPY_FILE="$PWD/src/cat-copy.json" CAT_TEST_INTERACTIVE="${CAT_TEST_INTERACTIVE:-1}" "$scratch/CatInteractionCheck" --self-test
