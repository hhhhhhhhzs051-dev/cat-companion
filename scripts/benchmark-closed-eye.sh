#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
closed_bench=$(mktemp -d "$PWD/reports/previews/closed-eye-bench.XXXXXXXX")
mkdir -p "$closed_bench/baseline"
mkdir -p "$closed_bench/baseline/src"
cp -R scripts/fixtures/build59/src/macos "$closed_bench/baseline/src/"
# Baseline renderer is verbatim build59, not the earlier accessory-cache candidate.
swiftc -O -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT -D CAT_CLOSED_REFERENCE "$closed_bench"/baseline/src/macos/*.swift scripts/closed-eye-window-tests.swift -framework AppKit -framework CoreImage -o "$closed_bench/build59"
swiftc -O -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/closed-eye-window-tests.swift -framework AppKit -framework CoreImage -o "$closed_bench/candidate"
print -r -- "$closed_bench"
if [[ "${1:-}" == --build-only ]]; then exit 0; fi
"$closed_bench/candidate"
for order in forward reverse; do
    for scene in idle head back early rest; do
        if [[ "$order" == forward ]]; then variants=(build59 candidate); else variants=(candidate build59); fi
        for variant in "${variants[@]}"; do
            /usr/bin/time -l "$closed_bench/$variant" --bench "$scene" > "$closed_bench/$order-$scene-$variant.log" 2>&1
            rg '^BENCH' "$closed_bench/$order-$scene-$variant.log"
        done
    done
done
