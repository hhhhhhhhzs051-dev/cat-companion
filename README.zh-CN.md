# 猫咪陪伴

一只住在 Mac 桌面上的小猫。点点猫头、持续抚摸，或者拿出小球，看它伸爪回应。每日摸猫和玩球可以积累成长、解锁外观奖励，缺席不会扣进度。

[English](README.md) · [构建与验证](docs/BUILDING.md) · [隐私说明](docs/PRIVACY.md)

## 下载与试用

**macOS 14+ · 中文界面 · 实验性手动安装版**

[下载 macOS 预览安装包](https://github.com/hhhhhhhhzs051-dev/cat-companion/releases/download/v1.1.1-preview.1/Cat-Companion-Open-Source-macOS-manual.zip) · [第一次试用](docs/TRY-IT.zh-CN.md) · [Release 下载页](https://github.com/hhhhhhhhzs051-dev/cat-companion/releases) · [演示说明](docs/DEMO.md)

ZIP 包内附应用、中文/英文安装说明和许可证。[下载 SHA-256 校验文件](https://github.com/hhhhhhhhzs051-dev/cat-companion/releases/download/v1.1.1-preview.1/SHA256SUMS.txt)。GitHub 自动生成的 Source code ZIP 不是可运行应用。预览包尚未经过 Apple 公证，另一台 Mac 的首次安装仍待验证。

![公开版原生渲染器生成的摸头闭眼演示](docs/media/head-pet.gif)

这是动作渲染演示，不是实机录屏；生成方式见[演示说明](docs/DEMO.md)。

## 使用与构建

需要 macOS 14 或更新版本、带 macOS SDK 的 Xcode Command Line Tools、Python 3，以及用于浏览器测试的 Node.js 18+。应用本身不需要安装第三方运行时依赖。界面和默认短句目前为中文。

```sh
zsh scripts/check-core.sh
zsh scripts/build-macos.sh
```

产物位于 `.build/macos/Cat Companion Open Source.app`，构建不会安装或启动它。开源版采用独立应用标识和存档目录，不读取原私人桌宠的存档。

也可以下载上方的预览安装包。默认本地签名尚未经过 Apple 公证，另一台 Mac 的首次运行、Intel 实机和长期多屏使用仍需验证。完整界面测试需要登录的 macOS 图形会话，过程中可能临时显示测试窗口。

## 功能

- 原生 Swift/AppKit 桌面窗口、分层画面、摸头、持续抚摸与玩球反馈。
- 本机成长记录、每日目标和外观奖励。
- 可选置顶、减少动态支持、独立信件阅读器。
- 无账户、遥测或应用网络服务；信件使用公开示例，可在构建前修改。

浏览器小样是早期的独立实现，功能与原生版并不完全一致。项目使用过 AI 辅助开发及素材生成，详见 [素材说明](ASSETS.md)。目前没有公开用户规模或社区采用数据。

代码与文档使用 MIT；美术素材使用 CC BY 4.0，适用范围及来源记录见 [ASSETS.md](ASSETS.md)。
