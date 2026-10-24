#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
node --test scripts/*.test.cjs
core_work=$(mktemp -d)
trap 'rm -rf "$core_work"' EXIT
for name in growth growth-store growth-migration; do
  swiftc src/macos/{CatGrowth,CatGrowthStore}.swift "scripts/$name-tests.swift" -o "$core_work/$name"
  "$core_work/$name"
done
swiftc src/macos/{CatGrowth,CatGrowthStore,CatLevel,CatPlayMood}.swift scripts/companion-progress-tests.swift -o "$core_work/progress"
"$core_work/progress"
for name in toy toy-parking toy-natural toy-continuity toy-two-paw toy-pull-spacing; do
  case "$name" in
    toy-pull-spacing) swiftc src/macos/CatToy.swift scripts/fixtures/PreviousTwoPawToy.swift "scripts/$name-tests.swift" -o "$core_work/$name" ;;
    *) swiftc src/macos/CatToy.swift "scripts/$name-tests.swift" -o "$core_work/$name" ;;
  esac
  "$core_work/$name"
done
print 'PASS public core tests'
