#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
growth_work=$(mktemp -d /tmp/cat-growth-tests.XXXXXXXX)
trap 'rm -rf "$growth_work"' EXIT
swiftc src/macos/CatGrowth.swift src/macos/CatGrowthStore.swift scripts/growth-tests.swift -o "$growth_work/model-tests"
"$growth_work/model-tests"
swiftc src/macos/CatGrowth.swift src/macos/CatGrowthStore.swift scripts/growth-store-tests.swift -o "$growth_work/store-tests"
"$growth_work/store-tests"
swiftc src/macos/CatGrowth.swift src/macos/CatGrowthStore.swift scripts/growth-migration-tests.swift -o "$growth_work/migration-tests"
"$growth_work/migration-tests"
swiftc -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/growth-production-tests.swift -framework AppKit -framework CoreImage -o "$growth_work/production-tests"
"$growth_work/production-tests"
swiftc -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/level-unopened-tests.swift -framework AppKit -framework CoreImage -o "$growth_work/unopened-production-tests"
"$growth_work/unopened-production-tests"
swiftc -D CAT_PLAY_PREVIEW -D CAT_GROWTH_PREVIEW -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/growth-integration-tests.swift -framework AppKit -framework CoreImage -o "$growth_work/integration-tests"
"$growth_work/integration-tests"
swiftc -O -D CAT_RENDER_TEST -D CAT_GROWTH_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/fixtures/Build48NativeCatView.swift scripts/toy-rest-render-tests.swift -framework AppKit -framework CoreImage -o "$growth_work/render-tests"
"$growth_work/render-tests"
swiftc -D CAT_PLAY_PREVIEW -D CAT_GROWTH_PREVIEW -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
swiftc -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST src/macos/*.swift scripts/accessory-persistence-tests.swift -framework AppKit -framework CoreImage -o "$growth_work/pair-persistence"
"$growth_work/pair-persistence"
print 'PASS growth preview Intel typecheck (not hardware verification)'
