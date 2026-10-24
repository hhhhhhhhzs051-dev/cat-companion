# 猫咪陪伴

一只住在 Mac 桌面上的小猫。点点猫头、持续抚摸，或者拿出小球，看它伸爪回应。每日摸猫和玩球可以积累成长、解锁外观奖励，缺席不会扣进度。

[English](README.md) · [构建与验证](docs/BUILDING.md) · [隐私说明](docs/PRIVACY.md)

## 使用与构建

需要 macOS 14 或更新版本、带 macOS SDK 的 Xcode Command Line Tools、Python 3，以及用于浏览器测试的 Node.js 18+。应用本身不需要安装第三方运行时依赖。界面和默认短句目前为中文。

```sh
zsh scripts/check-core.sh
zsh scripts/build-macos.sh
```

产物位于 `.build/macos/Cat Companion Open Source.app`，构建不会安装或启动它。开源版采用独立应用标识和存档目录，不读取原私人桌宠的存档。

这是源码发布。默认本地签名尚未经过 Apple 公证，另一台 Mac 的首次运行、Intel 实机和长期多屏使用仍需验证。完整界面测试需要登录的 macOS 图形会话，过程中可能临时显示测试窗口。

## 功能

- 原生 Swift/AppKit 桌面窗口、分层画面、摸头、持续抚摸与玩球反馈。
- 本机成长记录、每日目标和外观奖励。
- 可选置顶、减少动态支持、独立信件阅读器。
- 无账户、遥测或应用网络服务；信件使用公开示例，可在构建前修改。

浏览器小样是早期的独立实现，功能与原生版并不完全一致。项目使用过 AI 辅助开发及素材生成，详见 [素材说明](ASSETS.md)。目前没有公开用户规模或社区采用数据。

代码与文档使用 MIT；美术素材使用 CC BY 4.0，适用范围及来源记录见 [ASSETS.md](ASSETS.md)。
