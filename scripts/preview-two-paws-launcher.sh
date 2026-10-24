#!/bin/zsh
set -euo pipefail
preview_contents="${0:A:h:h}"
export CAT_TEST_RESOURCES="$preview_contents/Resources"
export CAT_TEST_COPY_FILE="$preview_contents/Resources/cat-copy.json"
exec "$preview_contents/MacOS/CatTwoPawPreview" --self-test
