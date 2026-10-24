#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
perf_preview=$(mktemp -d "$PWD/reports/previews/performance-app.XXXXXXXX")
perf_app="$perf_preview/流畅度对照预览（未安装）.app"
mkdir -p "$perf_app/Contents/MacOS" "$perf_app/Contents/Resources/assets"
swiftc -O -D CAT_PLAY_PREVIEW -D CAT_PERF_PREVIEW -D CAT_PAW_EXPERIMENT -target arm64-apple-macos14.0 src/macos/*.swift -framework AppKit -framework CoreImage -o "$perf_app/Contents/MacOS/CatPerformancePreview"
cp scripts/preview-performance-Info.plist "$perf_app/Contents/Info.plist"
cp src/assets/*.png "$perf_app/Contents/Resources/assets/"
cp src/assets/CatIcon.icns src/cat-copy.json src/letter.txt "$perf_app/Contents/Resources/"
codesign --force --sign - "$perf_app"
codesign --verify --deep --strict "$perf_app"
print -r -- "$perf_app"
