# Download and first launch

Requires **macOS 14 or newer**. The interface and default messages are in Chinese. The universal app contains Apple Silicon and Intel binaries, but Intel hardware and first installation on another Mac have not been tested. This native app does not run on Windows, iPhone or iPad.

## Install

1. Open [GitHub Releases](https://github.com/hhhhhhhhzs051-dev/cat-companion/releases), expand **Assets**, and look for `Cat-Companion-Open-Source-macOS-manual.zip`. If it is absent, [build from source](BUILDING.md). GitHub's automatic **Source code (zip)** download is not a runnable app.
2. Download the matching `SHA256SUMS.txt`. In Terminal, change to the download folder and run `shasum -a 256 -c SHA256SUMS.txt`; the ZIP should report `OK`. This checks file integrity, not notarization.
3. Extract the ZIP, drag **Cat Companion Open Source.app** to **Applications**, and open it there. Do not edit files inside the app bundle.
4. The preview is ad-hoc signed and **not notarized by Apple**. If macOS blocks it, verify the source and follow [Apple's guidance](https://support.apple.com/en-gb/102445). Only if you trust the download, use the app-specific **Open Anyway** option in **System Settings → Privacy & Security**. Stop if macOS reports malware, damage or an integrity failure. Do not disable Gatekeeper or remove quarantine attributes.

## First minute

| Action | Result |
| --- | --- |
| Click the cat's head | A brief closed-eye response |
| Hold and gently move over its head or back | Petting feedback that settles after release |
| Drag the blue-green bed | Move the desktop cat |
| Right-click and choose “拿出小绒球” | Bring out the ball; drag it near a paw and release |
| Choose “成长小窝” | View daily interaction goals and local progress; rewards require accumulated activity |
| Choose “给你的一封信” | Read the public example letter |

The menu also provides size controls, return-to-corner and optional always-on-top mode. The cat stays on the current desktop space and may not appear over fullscreen apps. “退出猫咪陪伴” quits; “收起桌面猫” hides it.

See the [rendered interaction demo](DEMO.md), generated from public code without private desktop or save data.

## Troubleshooting, updates and removal

- **Cat missing:** use the menu-bar cat entry to select “显示桌面猫”, then “设置 → 回到屏幕角落”.
- **Interaction unavailable:** check for “继续陪伴” in the menu; reduced-motion settings also limit some animations.
- **Only source files downloaded:** return to release Assets for the app ZIP, or follow the source build guide.
- **Update:** quit, keep a backup of local data, then replace the app in Applications. Do not delete Application Support when updating. Check the new release notes for compatibility limits.
- **Uninstall:** quit and move the app to Trash. Local records remain in `~/Library/Application Support/local.catcompanion.opensource/`; remove them yourself only if no longer needed. The open-source app uses a separate identifier and storage from the private edition.
- **Report a bug:** include macOS version, chip type, app version, steps and expected/actual behavior in [Issues](https://github.com/hhhhhhhhzs051-dev/cat-companion/issues/new/choose). Redact desktop details, names and letters from screenshots; do not upload real save files.

Long sessions and multiple displays remain unverified. Local checks do not establish cross-machine compatibility.
