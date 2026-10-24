#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/docs
flags=(-D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY -D CAT_PUPIL_RECOVERY -D CAT_EYE_HANDOFF -D CAT_GRAB_HANDOFF)
swiftc -O $flags src/macos/{CatToy,NativeCat,CatMotion,CatDeformation,CatMouth,CatMouthArt,CatPaw,CatPawArt,CatPawRig,CatGrooming,CatEyeGaze,CatPupilArt,CatEyeHandoff}.swift scripts/render-demo.swift -framework AppKit -framework CoreImage -o .build/docs/render-demo
.build/docs/render-demo
# ImageIO adds an EXIF container even for new bitmap frames. Keep the encoded
# image/color chunks intact and omit that metadata from documentation copies.
python3 - <<'PY'
from pathlib import Path
for name in ('rest.png', 'head-pet.png'):
    path = Path('docs/media') / name
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    output = bytearray(data[:8])
    position = 8
    while position < len(data):
        size = int.from_bytes(data[position:position + 4], 'big')
        end = position + size + 12
        assert end <= len(data)
        if data[position + 4:position + 8] != b'eXIf':
            output.extend(data[position:end])
        position = end
    path.write_bytes(output)
PY
