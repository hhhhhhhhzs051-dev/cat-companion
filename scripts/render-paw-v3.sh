#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
swiftc -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/render-paw-v3.swift -framework AppKit -framework CoreImage -o "$work/paw-render"
"$work/paw-render"
