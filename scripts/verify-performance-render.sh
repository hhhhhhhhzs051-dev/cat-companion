#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
perf_work=$(mktemp -d "$PWD/reports/previews/render-perf.XXXXXXXX")
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/fixtures/Build56NativeCatView.swift scripts/performance-render-tests.swift -framework AppKit -framework CoreImage -o "$perf_work/render-tests"
print -r -- "$perf_work/render-tests"
"$perf_work/render-tests" check
