#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
bench_work=$(mktemp -d /tmp/cat-toy-rest.XXXXXXXX)
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/fixtures/Build48NativeCatView.swift scripts/toy-rest-render-tests.swift -framework AppKit -framework CoreImage -o "$bench_work/bench"
"$bench_work/bench"
for mode in baseline-idle preview-ball baseline-ball preview-ball baseline-idle baseline-ball baseline-ball baseline-idle preview-ball; do
  /usr/bin/time -l "$bench_work/bench" "$mode"
done
