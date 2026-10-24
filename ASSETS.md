# Artwork and provenance

The cat is drawn using raster layers, masks and native transforms. It is not a skeletal 3D rig. The project used AI image generation and local compositing; original production prompts and some generation records are incomplete. No private reference photographs or generation-session records are distributed.

| Files | Recorded provenance |
| --- | --- |
| `cat-d.png`, `cat-closed.png`, `empty-bed.png` | Retained project illustrations; local records describe AI-assisted edits for the cat, closed eyelids and the empty bed. |
| `bed-complete-v2.png` | Retained approved project raster; exact historical generation record is unavailable. |
| `cat-icon.png`, `CatIcon.icns` | Project icon and format conversion; exact original generation record is unavailable. |
| `cat-paw-contact-v1.png`, `cat-tongue-v1.png`, `letter-stationery-v1.png` | Retained project raster assets; per-file original generation records were not established during public preparation. |

The inventory in `docs/asset-inventory.json` identifies the distributed bytes. It does not prove ownership or complete rights clearance. The project maintainer must confirm authority to license the included artwork before publication. The proposed public license is described in [ASSETS-LICENSE.md](ASSETS-LICENSE.md).

Raster regression fixtures under `scripts/fixtures/` are derived project artwork/render references and use the artwork license as well. EXIF metadata was removed from the six approved-paw fixtures, and embedded C2PA generation manifests were removed from public raster copies without changing encoded pixel data. These files no longer carry their original embedded authenticity manifests; AI-assisted provenance remains disclosed here.

No third-party font files are bundled. The native reader uses fonts already installed on the user's Mac, with a system fallback. The illustration shown in the README is a source asset, not a live UI capture.

Documentation images under `docs/media/` are generated from the public renderer and source artwork using `scripts/render-demo.sh`. They use the same artwork license. The GIF is an offscreen head-pet sequence, not a screen recording; see [demo details](docs/DEMO.md).
