# WinKey

WinKey 是一个 macOS 菜单栏小工具，用来让外接 Windows/PC 键盘保留常用操作习惯。它把常见 Windows 快捷键转换成 macOS 对应操作，适合刚从 Windows 迁移到 Mac、但仍使用外接 PC 键盘的人。

## 功能

- Finder 中按 PC 键盘的 `Delete` 时，确认后将所选文件移到废纸篓。
- 按 `PrtSc` 全屏截图，并按当前时间命名保存到桌面。
- 按 `Option + A` 或 `Command + A` 触发 macOS 基础区域截图，截图按当前时间命名保存到桌面，并同时复制到剪贴板；可在菜单中切换触发键。
- 按 `Ctrl + A` 映射为 macOS 的全选。
- 支持常用 Windows `Ctrl` 快捷键：复制、粘贴、剪切、撤销、重做、查找、保存、打印、关闭、新建标签、新建窗口、打开、刷新、恢复关闭标签、新建文件夹。
- 在文本输入区域中支持 `Home` / `End`、`Ctrl + Left/Right`、`Ctrl + Home/End` 的 Windows 风格导航。
- 可选开启 `Alt + Tab` 到 `Command + Tab` 的应用切换映射，默认关闭。
- 可选反转滚动方向，适合不习惯 macOS 自然滚动的用户。
- 可选防止系统因闲置进入睡眠；显示器仍可按系统设置息屏。
- 可选在连接外接显示器时，通过鼠标移动、点击或滚轮主动报告用户活跃，帮助唤醒息屏后的显示输出。
- 菜单默认为英文，可在菜单中切换为中文。
- 菜单栏常驻，支持单项开关和开机启动开关。

## 系统要求

- macOS 13 或更新版本
- 一把外接 Windows/PC 键盘
- 需要开启 macOS “辅助功能”权限
- 若使用滚动方向反转，需要开启 macOS “输入监控”权限

## 构建

```sh
swift build
```

生成 `.app`：

```sh
scripts/build-app.sh
```

构建结果位于 `dist/WinKey.app`。

## 安装与使用

### 下载预编译版

前往 GitHub Releases 页面下载最新的 `WinKey-x.y.z.zip`：

https://github.com/kveinjay-google/winkey/releases

下载后解压 `WinKey.app`，按下面的“从源码构建”或直接拖到 `/Applications` 后右键打开（当前为 ad-hoc 签名，需要 macOS 14+ 或在 系统设置 → 隐私与安全性 中允许打开）。

### 从源码构建

1. 运行 `scripts/build-app.sh` 生成 `dist/WinKey.app`。
2. 将 `dist/WinKey.app` 拖到 `/Applications`。
3. 启动 WinKey。
4. 在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中允许 WinKey。
5. 从菜单栏图标打开菜单，按需开启或关闭各项映射。

## 权限

WinKey 使用 macOS 辅助功能权限监听全局键盘事件，并把 Windows 风格快捷键转换成 macOS 快捷键。滚动方向反转还需要输入监控权限。首次启动时，如果未授权，会显示中文引导窗口；也可以从菜单栏中打开系统设置。

WinKey 不上传键盘输入，不连接网络，也不保存你的按键内容。配置仅存储在本机 `UserDefaults` 中。

## 说明

部分 PC 键盘会把 `PrtSc` 报告为 `F13`，这是当前版本支持的默认映射。如果某些键盘厂商使用其他键码，后续可以在设置中扩展自定义键码。

当前仓库生成的是本地开发版 `.app`，使用 ad-hoc 签名。公开分发时建议使用 Apple Developer ID 签名并进行 notarization。

滚动方向反转使用 CoreGraphics 事件 tap，并参考了 [Scroll Reverser](https://github.com/pilotmoon/Scroll-Reverser) 的做法，同时修改 CGEvent 滚动 delta 与底层 IOHID 滚动字段。

防止闲置睡眠使用 macOS IOKit 的 `PreventUserIdleSystemSleep` assertion。它只阻止因无人操作导致的系统睡眠；合盖、Apple 菜单睡眠、低电量、过热等强制睡眠仍由 macOS 控制。鼠标唤醒外接显示器使用 `IOPMAssertionDeclareUserActivity` 报告本地用户活跃；如果 Mac 已经真正进入系统睡眠，应用本身无法运行，因此无法替代硬件/系统级唤醒。

## 许可证

本项目使用 MIT License，详见 [LICENSE](LICENSE)。
