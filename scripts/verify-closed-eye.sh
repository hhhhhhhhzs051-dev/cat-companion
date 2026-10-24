#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p reports/previews
closed_check=$(mktemp -d "$PWD/reports/previews/closed-eye-check.XXXXXXXX")
# Mechanical fixture generation from the immutable formal source, never current.
cat scripts/fixtures/build59/src/macos/NativeCat.swift |
    sed -e 's/NativeCatView/Build59NativeCatView/g' -e 's/CatIdleFrameCache/Build59IdleFrameCache/g' > "$closed_check/Build59NativeCatView.swift"
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
    src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift \
    "$closed_check/Build59NativeCatView.swift" scripts/closed-eye-reuse-tests.swift \
    -framework AppKit -framework CoreImage -o "$closed_check/check"
print -r -- "$closed_check"
"$closed_check/check"
swiftc -O -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT \
    src/macos/*.swift scripts/closed-eye-window-tests.swift \
    -framework AppKit -framework CoreImage -o "$closed_check/window-check"
"$closed_check/window-check"
