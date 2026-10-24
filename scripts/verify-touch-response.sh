#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
touch_work=$(mktemp -d /tmp/cat-touch-verification.XXXXXXXX)
trap 'rm -rf "$touch_work"' EXIT
swiftc -D CAT_PAW_EXPERIMENT src/macos/{CatMotion,CatMouth,CatPaw,CatGrooming}.swift scripts/touch-response-tests.swift -o "$touch_work/model"
"$touch_work/model"
# Exercise the existing native input/eye/menu regression suite with the opt-in
# enabled in every fresh model, without changing its accepted assertions.
sed -E 's/CatMotion\(([^)]*)\)/CatMotion(\1,refinedTouch:true)/g' scripts/menu-tests.swift > "$touch_work/touch-menu-tests.swift"
mkdir -p "$touch_work/assets"
cp src/letter.txt "$touch_work/letter.txt"
cp src/assets/letter-stationery-v1.png "$touch_work/assets/"
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_TOUCH_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift "$touch_work/touch-menu-tests.swift" -framework AppKit -framework CoreImage -o "$touch_work/integration"
"$touch_work/integration"
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/touch-response-render-tests.swift -framework AppKit -framework CoreImage -o "$touch_work/render"
"$touch_work/render"
