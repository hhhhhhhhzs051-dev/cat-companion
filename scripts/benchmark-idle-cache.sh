#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
# Sequential real NativeCatView render replay; no duplicate .app or user settings.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
  src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
  scripts/fixtures/LegacyNativeCatView.swift scripts/idle-cache-tests.swift \
  -framework AppKit -framework CoreImage -o "$work/idle-cache"
"$work/idle-cache"
for mode in old new new old old new; do
  /usr/bin/time -l "$work/idle-cache" "$mode"
done
