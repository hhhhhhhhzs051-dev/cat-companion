# Open-source macOS preview 1.1.1

A native desktop cat with head petting, stroking, ball play, local growth goals and cosmetic rewards. The interface is in Chinese. This release packages the initial public source snapshot; it does not include later changes from the private edition.

## Downloads

- `Cat-Companion-Open-Source-macOS-manual.zip`: runnable universal macOS application plus English/Chinese installation instructions and licenses.
- `SHA256SUMS.txt`: SHA-256 checksum for the ZIP.

Requires macOS 14+. Read the [English installation guide](TRY-IT.md) / [中文安装说明](TRY-IT.zh-CN.md). GitHub's automatically generated Source code archives are for developers, not app installers.

## Verified scope

The packaged app's source and resource hashes match the public source tree. Both arm64 and x86_64 executables are present, and strict local signature verification passes. The prior full local build and isolated binary self-test passed; the background minimize check reported SKIP. This documentation update does not modify the application source or binary.

The embedded manifest identifies the initial build as `uncommitted-public-snapshot`. Its per-source hashes were checked against the published source snapshot at `533b6d0a7951f6edc1a1d401e3b79cbac76b67ca`; it should not be interpreted as a build from a later documentation commit.

## Known limits

The app is ad-hoc signed and **not Apple-notarized**. Gatekeeper assessment on the maintainer's Mac rejects it. Another Mac's first installation, Intel hardware, long sessions and multiple displays remain unverified. This preview does not provide automatic updates. It uses its own `local.catcompanion.opensource` data namespace and contains a neutral example letter, not private user content.

[Rendered demo](DEMO.md) · [Privacy](PRIVACY.md) · [Report a bug](https://github.com/hhhhhhhhzs051-dev/cat-companion/issues/new/choose)


## 中文说明

这是猫咪陪伴的首个开源 macOS 预览安装包，包含摸头、抚摸、玩球、本机成长目标和外观奖励。界面为中文，需要 macOS 14 或更新版本。应用沿用首次公开的源码版本，不包含私人版后续更新。

### 下载与使用

下载 Assets 中的 `Cat-Companion-Open-Source-macOS-manual.zip` 和 `SHA256SUMS.txt`。解压后，把 **Cat Companion Open Source.app** 拖入“应用程序”，再打开。包内附中文、英文和纯文本说明。GitHub 自动生成的 Source code ZIP 是源码，不是可运行安装包。

点猫头摸摸，拖猫窝移动；右键点猫，选择“拿出小绒球”玩球，选择“成长小窝”查看目标与奖励。完整步骤见 [中文安装说明](TRY-IT.zh-CN.md)。

### 核验与限制

已核对公开源码与包内资源哈希、Apple Silicon / Intel 双架构、严格本地签名完整性和 ZIP 文件完整性。此前完整本机构建和隔离二进制自测通过，后台最小化检查为 SKIP。本次仅补文档及安装分发，不修改应用代码或二进制。

**尚未经过 Apple 公证，Gatekeeper 检查拒绝。** 另一台 Mac 首次安装、Intel 实机、长期及多屏使用仍未验证。不要关闭系统安全保护或运行解除隔离脚本。公开版使用独立存档目录和中性示例信件，不含私人存档、信件或设置。

内嵌构建清单记录为 `uncommitted-public-snapshot`；已按其中的逐源码哈希与上述首次公开提交核对，不把它声称为后来文档提交重新构建的应用。
