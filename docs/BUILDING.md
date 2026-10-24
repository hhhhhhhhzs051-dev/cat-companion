# Build and test

## Requirements

- macOS 14 or newer and an active macOS SDK (`xcrun --show-sdk-version`).
- Xcode Command Line Tools / Swift compiler; Python 3 for manifests and local tooling.
- Node.js 18+ for the dependency-free JavaScript tests.
- Full GUI tests need a logged-in desktop session. They may bring test windows to the foreground; run them when you are not interacting with other applications.

## Commands

```sh
zsh scripts/check-core.sh
zsh scripts/verify.sh
zsh scripts/build-macos.sh
python3 scripts/check-bundle.py '.build/macos/Cat Companion Open Source.app'
python3 scripts/audit-public.py
```

`build-macos.sh` runs the full `verify.sh` suite before compiling both arm64 and x86_64 for macOS 14. The production feature flags are kept together in the build script and manifest. Outputs, temporary UI frames and reports are ignored by Git. An existing output is recoverably archived before replacement. The build neither installs nor launches the result.

This source-only public distribution uses `local.catcompanion.opensource`, including its separate Application Support directory. Do not change this back to an existing private installation's identifier during testing.

## Signatures and limitations

Local builds use ad-hoc signing unless a signing identity is explicitly configured. No signing credentials are distributed. A successful local signature check does not establish Gatekeeper trust or notarization. There is no prebuilt notarized download in this snapshot and no automatic security-setting changes or quarantine-removal instructions.

Cross-compilation checks Intel syntax and linking, not Intel hardware behavior. Fullscreen, multiple screens, long sessions and installation on another Mac require separate manual validation. Some lifecycle tests may explicitly report SKIP when the required desktop scene cannot be established; preserve and report those skips.

## Browser prototype

`src/index.html` and its sibling JS/CSS files contain an earlier independent browser prototype. `node scripts/build.cjs` exports a self-contained prototype under ignored reports. It does not mirror the native application's complete feature set or its current settings.
