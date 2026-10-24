"""Check that a built app is the current source release, without launching it."""
import hashlib
import json
import plistlib
import sys
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


app = Path(sys.argv[1])
resources = app / 'Contents' / 'Resources'
info = plistlib.loads((app / 'Contents' / 'Info.plist').read_bytes())
manifest = json.loads((resources / 'build-manifest.json').read_text(encoding='utf-8'))
version = Path('VERSION').read_text(encoding='utf-8').strip()
if info['CFBundleShortVersionString'] != version or manifest['version'] != version:
    raise SystemExit('App, manifest and VERSION disagree')
if manifest['deployment_target'] != '14.0' or manifest['architectures'] != ['arm64', 'x86_64']:
    raise SystemExit('Unexpected deployment target or architectures in manifest')
source_files = sorted(path for path in Path('src').rglob('*') if path.is_file())
if manifest.get('swift_defines') != ['CAT_PAW_EXPERIMENT', 'CAT_ACCESSORY_GAZE', 'CAT_EYE_INTERACTION', 'CAT_PUPIL_PLAY', 'CAT_PUPIL_RECOVERY', 'CAT_EYE_HANDOFF', 'CAT_GRAB_HANDOFF']:
    raise SystemExit('Unexpected release compile definitions')
expected = {str(path): digest(path) for path in source_files}
if manifest['source_sha256'] != expected:
    raise SystemExit('The app was not built from the current source files')
resource_sources = {'src/cat-copy.json': resources / 'cat-copy.json',
                    'src/letter.txt': resources / 'letter.txt',
                    'src/assets/CatIcon.icns': resources / 'CatIcon.icns'}
resource_sources.update({str(path): resources / 'assets' / path.name
                         for path in Path('src/assets').glob('*.png')})
for source, bundled in resource_sources.items():
    if digest(Path(source)) != digest(bundled):
        raise SystemExit(f'Bundled resource differs from {source}')
print(f"PASS bundle matches source: {version} ({info['CFBundleVersion']})")
