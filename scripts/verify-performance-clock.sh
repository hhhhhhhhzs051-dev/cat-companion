#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
perf_clock=$(mktemp -d "$PWD/reports/previews/clock-perf.XXXXXXXX")
swiftc -O -D CAT_RENDER_TEST -D CAT_PLAY_PREVIEW -D CAT_PERF_PREVIEW -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/performance-clock-tests.swift -framework AppKit -framework CoreImage -o "$perf_clock/clock-tests"
print -r -- "$perf_clock/clock-tests"
"$perf_clock/clock-tests" --self-test "$@"
