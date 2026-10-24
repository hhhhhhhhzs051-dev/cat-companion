#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
node --test scripts/*.test.cjs
zsh scripts/verify-growth.sh
zsh scripts/verify-level.sh
zsh scripts/verify-roll-in.sh
zsh scripts/verify-touch-release.sh
zsh scripts/verify-accessory-preview.sh
zsh scripts/verify-accessory-look.sh
zsh scripts/verify-accessory-eye.sh
zsh scripts/verify-continuous-gaze.sh
zsh scripts/verify-gaze-release.sh
zsh scripts/verify-eye-interaction-release.sh
zsh scripts/verify-pupil-play-release.sh
zsh scripts/verify-pupil-recovery-release.sh
zsh scripts/verify-eye-handoff-release.sh
zsh scripts/verify-grab-handoff.sh
zsh scripts/verify-grab-handoff-release.sh
zsh scripts/verify-background-eyes.sh
zsh scripts/verify-eye-gaze.sh
zsh scripts/verify-eye-animation.sh
zsh scripts/verify-closed-eye.sh
zsh scripts/verify-companion.sh
for file in scripts/*.sh; do zsh -n "$file"; done
for file in scripts/*.py; do python3 -c 'import ast,sys;ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$file"; done
for file in src/*.js scripts/build.cjs; do node --check "$file"; done
swiftc -typecheck -target arm64-apple-macos14.0 src/macos/*.swift
swiftc -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
swiftc -D CAT_PAW_EXPERIMENT -typecheck -target arm64-apple-macos14.0 src/macos/*.swift
swiftc -D CAT_PAW_EXPERIMENT -typecheck -target x86_64-apple-macos14.0 src/macos/*.swift
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Give the standalone real-menu harness its actual letter resources, without
# switching on self-test lifecycle shortcuts or creating a duplicate .app.
mkdir -p "$work/assets"
cp src/letter.txt "$work/letter.txt"
cp src/assets/letter-stationery-v1.png "$work/assets/"
swiftc -D CAT_MENU_TEST -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/menu-tests.swift -framework AppKit -framework CoreImage -o "$work/menu-tests"
"$work/menu-tests"
swiftc src/macos/CatPlayMood.swift scripts/play-mood-tests.swift -o "$work/play-mood-tests"
"$work/play-mood-tests"
swiftc src/macos/CatPlayMood.swift src/macos/CatToy.swift scripts/play-mood-result-tests.swift -o "$work/play-result-tests"
"$work/play-result-tests"
swiftc -D CAT_MENU_TEST -D CAT_PLAY_PREVIEW -D CAT_PAW_EXPERIMENT src/macos/*.swift scripts/context-feedback-integration-tests.swift -framework AppKit -framework CoreImage -o "$work/context-feedback-tests"
"$work/context-feedback-tests"
swiftc src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/letter-tests.swift -framework AppKit -o "$work/letter-tests"
"$work/letter-tests"
swiftc src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/letter-content-tests.swift -framework AppKit -o "$work/letter-content-tests"
"$work/letter-content-tests"
swiftc src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/letter-stationery-tests.swift -framework AppKit -o "$work/letter-stationery-tests"
"$work/letter-stationery-tests"
swiftc src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/letter-opening-tests.swift -framework AppKit -o "$work/letter-opening-tests"
"$work/letter-opening-tests"
swiftc src/macos/CatLetter.swift src/macos/CatLetterDrift.swift scripts/LetterOpeningDrift.swift scripts/letter-drift-tests.swift -framework AppKit -o "$work/letter-drift-tests"
"$work/letter-drift-tests"
swiftc src/macos/CatToy.swift src/macos/NativeCat.swift src/macos/CatMotion.swift src/macos/CatDeformation.swift src/macos/CatMouth.swift src/macos/CatMouthArt.swift scripts/native-core-tests.swift -framework AppKit -framework CoreImage -o "$work/native-core-tests"
"$work/native-core-tests"
swiftc src/macos/CatMouth.swift src/macos/CatMotion.swift scripts/mouth-tests.swift -o "$work/mouth-tests"
"$work/mouth-tests"
swiftc src/macos/CatMotion.swift src/macos/CatMouth.swift scripts/fixtures/LegacyCatMotion.swift scripts/back-eye-tests.swift -o "$work/back-eye-tests"
"$work/back-eye-tests"
swiftc -D CAT_PAW_EXPERIMENT src/macos/CatMouth.swift src/macos/CatMouthArt.swift scripts/fixtures/LegacyMouthArt.swift scripts/mouth-render-tests.swift -framework AppKit -framework CoreImage -o "$work/mouth-render-tests"
"$work/mouth-render-tests"
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/fixtures/LegacyNativeCatView.swift scripts/idle-cache-tests.swift -framework AppKit -framework CoreImage -o "$work/idle-cache-tests"
"$work/idle-cache-tests"
swiftc -O -D CAT_RENDER_TEST -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/fixtures/Build48NativeCatView.swift scripts/toy-rest-render-tests.swift -framework AppKit -framework CoreImage -o "$work/toy-rest-render-tests"
"$work/toy-rest-render-tests"
swiftc -D CAT_PAW_EXPERIMENT src/macos/CatPaw.swift src/macos/CatPawRig.swift scripts/paw-tests.swift -o "$work/paw-tests"
"$work/paw-tests"
swiftc -D CAT_PAW_EXPERIMENT src/macos/CatGrooming.swift src/macos/CatPaw.swift src/macos/CatMouth.swift src/macos/CatMotion.swift src/macos/CatDeformation.swift scripts/grooming-tests.swift -o "$work/grooming-tests"
"$work/grooming-tests"
swiftc -D CAT_PAW_EXPERIMENT src/macos/{CatGrooming,CatPaw,CatMouth,CatMotion}.swift scripts/grooming-integration-tests.swift -o "$work/grooming-integration-tests"
"$work/grooming-integration-tests"
swiftc -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/native-core-tests.swift -framework AppKit -framework CoreImage -o "$work/native-integrated-tests"
"$work/native-integrated-tests"
swiftc src/macos/CatToy.swift scripts/toy-tests.swift -o "$work/toy-tests"
"$work/toy-tests"
swiftc scripts/fixtures/PreOuterCatToy.swift scripts/fixtures/AcceptedBuild48Toy.swift scripts/OriginalPawPlayback.swift scripts/original-paw-playback-tests.swift -o "$work/original-paw-playback-tests"
"$work/original-paw-playback-tests"
swiftc src/macos/CatToy.swift scripts/fixtures/PreOuterCatToy.swift scripts/OriginalPawPlayback.swift scripts/toy-approved-preview-tests.swift -o "$work/toy-approved-preview-tests"
"$work/toy-approved-preview-tests"
swiftc src/macos/CatToy.swift scripts/toy-parking-tests.swift -o "$work/toy-parking-tests"
"$work/toy-parking-tests"
swiftc src/macos/CatToy.swift scripts/toy-natural-tests.swift -o "$work/toy-natural-tests"
"$work/toy-natural-tests"
swiftc src/macos/CatToy.swift scripts/toy-continuity-tests.swift -o "$work/toy-continuity-tests"
"$work/toy-continuity-tests"
swiftc src/macos/CatToy.swift scripts/toy-push-pull-tests.swift -o "$work/toy-push-pull-tests"
"$work/toy-push-pull-tests"
swiftc src/macos/CatToy.swift scripts/toy-response-tests.swift -o "$work/toy-response-tests"
"$work/toy-response-tests"
swiftc src/macos/CatToy.swift scripts/toy-wide-reach-tests.swift -o "$work/toy-wide-reach-tests"
"$work/toy-wide-reach-tests"
swiftc src/macos/CatToy.swift scripts/toy-two-paw-tests.swift -o "$work/toy-two-paw-tests"
"$work/toy-two-paw-tests"
swiftc src/macos/CatToy.swift scripts/fixtures/LegacySinglePawToy.swift scripts/toy-single-paw-baseline-tests.swift -o "$work/toy-single-paw-baseline-tests"
"$work/toy-single-paw-baseline-tests"
swiftc src/macos/CatToy.swift scripts/fixtures/PreviousTwoPawToy.swift scripts/toy-pull-spacing-tests.swift -o "$work/toy-pull-spacing-tests"
"$work/toy-pull-spacing-tests"
swiftc -O -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/fixtures/LegacyBuild47PawArt.swift scripts/paw-render-tests.swift -framework AppKit -framework CoreImage -o "$work/paw-render-tests"
"$work/paw-render-tests"
swiftc -O -D CAT_PAW_EXPERIMENT src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming}.swift scripts/approved-paw-render-tests.swift -framework AppKit -framework CoreImage -o "$work/approved-paw-render-tests"
"$work/approved-paw-render-tests"
