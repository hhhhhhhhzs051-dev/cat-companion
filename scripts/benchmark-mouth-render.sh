#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
# Sequential, bounded local microbenchmark. Not whole-app idle CPU or live RSS.
# Build 33's legacy TIFF path can transiently retain roughly 6 GiB on this Mac.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swiftc -O -D CAT_PAW_EXPERIMENT src/macos/CatMouth.swift src/macos/CatMouthArt.swift \
  scripts/fixtures/LegacyMouthArt.swift scripts/mouth-render-tests.swift \
  -framework AppKit -framework CoreImage -o "$work/mouth-render"
"$work/mouth-render" check
for mode in old new new old old new; do
  /usr/bin/time -l "$work/mouth-render" "$mode"
done
