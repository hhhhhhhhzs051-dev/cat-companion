#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
receipt_work=$(mktemp -d /tmp/cat-receipt-verify.XXXXXXXX)
print "Evidence: $receipt_work"
receipt_flags=(-suppress-warnings -D CAT_PLAY_PREVIEW -D CAT_PAW_EXPERIMENT -D CAT_MENU_TEST)
swiftc -parse-as-library scripts/receipt-external-cover.swift -framework AppKit -o "$receipt_work/external-cover"
swiftc $receipt_flags src/macos/*.swift scripts/completion-window-support.swift scripts/completion-window-tests.swift -framework AppKit -framework CoreImage -o "$receipt_work/window-tests"
CAT_RECEIPT_COVER_HELPER="$receipt_work/external-cover" "$receipt_work/window-tests" | tee "$receipt_work/window.log"
for negative in missing-cover transparent-cover; do
  set +e
  CAT_RECEIPT_NEGATIVE="$negative" "$receipt_work/window-tests" > "$receipt_work/$negative.log" 2>&1
  receipt_status=$?
  set -e
  if [[ $receipt_status != 2 ]] || ! rg -q 'INVALID_SCENE' "$receipt_work/$negative.log"; then
    print -u2 "FAIL negative control $negative: expected invalid-scene exit 2, got $receipt_status"
    exit 1
  fi
  print "PASS negative control: $negative rejected as invalid scene"
done
# No --self-test: actual NSWindowDelegate occlusion drives syncActivity.
swiftc $receipt_flags src/macos/*.swift scripts/completion-window-support.swift scripts/completion-space-window-tests.swift -framework AppKit -framework CoreImage -o "$receipt_work/space-tests"
"$receipt_work/space-tests" "${@}" | tee "$receipt_work/space.log"
