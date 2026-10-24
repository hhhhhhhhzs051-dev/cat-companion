#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
out="${CAT_OUTPUT_DIR:-$PWD/.build/macos}"
version="$(<VERSION)"
if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 'VERSION必须是X.Y.Z格式'; exit 1
fi
mkdir -p "$out"
lock="$out/.build-lock"
if ! mkdir "$lock" 2>/dev/null; then
  print -u2 "已有构建锁：$lock；持有PID：$(cat "$lock/pid" 2>/dev/null || print unknown)。确认进程退出后才能清理锁。"
  exit 1
fi
work=''
trap '[[ -z "$work" ]] || rm -rf "$work"; rm -f "$lock/pid"; rmdir "$lock"' EXIT
print $$ > "$lock/pid"
work=$(mktemp -d "$out/.build.XXXXXX")
app="$work/猫咪陪伴.build"
final="$out/Cat Companion Open Source.app"
if ps -axo comm= | /usr/bin/grep -F -x -- "$final/Contents/MacOS/CatCompanion" >/dev/null; then
  print -u2 '请先退出猫咪陪伴再构建；正式版本未修改。'; exit 1
fi
zsh scripts/verify.sh
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -D CAT_PAW_EXPERIMENT -D CAT_ACCESSORY_GAZE -D CAT_EYE_INTERACTION -D CAT_PUPIL_PLAY -D CAT_PUPIL_RECOVERY -D CAT_EYE_HANDOFF -D CAT_GRAB_HANDOFF -target "$arch-apple-macos14.0" src/macos/*.swift -o "$work/$arch" -framework AppKit -framework CoreImage -O
done
lipo -create "$work/arm64" "$work/x86_64" -output "$app/Contents/MacOS/CatCompanion"
cp src/assets/CatIcon.icns "$app/Contents/Resources/CatIcon.icns"
cp src/cat-copy.json "$app/Contents/Resources/"
cp src/letter.txt "$app/Contents/Resources/"
mkdir -p "$app/Contents/Resources/assets"
cp src/assets/*.png "$app/Contents/Resources/assets/"
if [[ ! -f "$out/猫咪文案.json" ]]; then cp src/cat-copy.json "$out/猫咪文案.json"; fi
cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CatCompanion</string>
<key>CFBundleIdentifier</key><string>local.catcompanion.opensource</string>
<key>CFBundleName</key><string>Cat Companion Open Source</string>
<key>CFBundleDisplayName</key><string>Cat Companion Open Source</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>CatIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><false/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
python3 scripts/build-manifest.py "$app/Contents/Resources/build-manifest.json" "$out"
if [[ "${CAT_SIGN_IDENTITY:--}" == - ]]; then
  codesign --force --sign - "$app"
else
  codesign --force --options runtime --timestamp --sign "$CAT_SIGN_IDENTITY" "$app"
fi
codesign --verify --deep --strict "$app"
if [[ -e "$final" ]]; then
  mkdir -p "$out/../archives"
  ditto -c -k --keepParent "$final" "$out/../archives/cat-$(date +%Y%m%d-%H%M%S).zip"
fi
if [[ "${CAT_TEST_FAIL_INSTALL:-0}" == 1 ]]; then print -u2 'Injected pre-install failure';exit 9;fi
python3 scripts/install-bundle.py "$app" "$final"
touch "$final"
print "Built and verified: $final"
