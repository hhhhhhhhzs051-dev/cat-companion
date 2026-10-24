#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
if (( $# != 1 )); then
  print -u2 "Usage: zsh scripts/preview-letter-drift.sh EXISTING_EMPTY_PREVIEW_OUTPUT"
  exit 2
fi
out="${1:A}"
preview_root="$PWD/reports/previews"
[[ "$out" == "$preview_root"/letter-drift.* && -d "$out" ]] || { print -u2 "Not a dedicated letter drift preview directory"; exit 2; }
app="$out/信纸飘落预览（未安装）.app"
[[ ! -e "$app" ]] || { print -u2 "Preview already exists; inspect before rebuilding"; exit 2; }
swiftc -O -target arm64-apple-macos14.0 src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/LetterOpeningDrift.swift scripts/letter-drift-tests.swift -framework AppKit -framework QuartzCore -o "$out/drift-tests"
"$out/drift-tests"
swiftc -typecheck -target x86_64-apple-macos14.0 src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/LetterOpeningDrift.swift scripts/preview-letter-drift.swift
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp scripts/preview-letter-drift-Info.plist "$app/Contents/Info.plist"
cp src/assets/letter-stationery-v1.png "$app/Contents/Resources/stationery.png"
swiftc -O -target arm64-apple-macos14.0 src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/LetterOpeningDrift.swift scripts/preview-letter-drift.swift -framework AppKit -framework QuartzCore -o "$app/Contents/MacOS/CatLetterDriftPreview"
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
print "Built isolated preview: $app"
