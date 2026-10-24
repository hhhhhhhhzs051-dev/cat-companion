#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-$PWD/.build/macos/Cat Companion Open Source.app}"
print '检查包完整性…'
codesign --verify --deep --strict "$app"
print '检查双架构…'
for arch in arm64 x86_64; do lipo -verify_arch "$arch" "$app/Contents/MacOS/CatCompanion"; done
print '检查Gatekeeper信任…'
spctl --assess --type execute "$app"
print '检查公证装订票据…'
xcrun stapler validate "$app"
print '包校验通过；另一台Mac首次安装仍需实测。'
