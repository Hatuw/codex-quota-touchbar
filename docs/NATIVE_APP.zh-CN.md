# 原生 App

[English](NATIVE_APP.md) | [中文](NATIVE_APP.zh-CN.md)

本仓库也包含一个小型 AppKit App。

原生 App 可以在 Touch Bar 中显示真正的圆角进度条，但它有一个重要的 macOS 限制：普通 App 只能在自己处于激活状态时提供 Touch Bar 内容。

如果你希望额度组件全局常驻，请使用 MTMR 方案。

## 构建

```bash
./scripts/build_app.sh
```

App bundle 会输出到：

```text
outputs/CodexQuotaTouchBar.app
```

## 运行

打开生成的 App，并点击它的窗口，让它成为当前激活 App。此时它的自定义 Touch Bar 项目应该会出现。

这个 App 和 MTMR helper 读取相同的数据源：

1. `~/.codex/sessions` 下最新的 Codex `rate_limits` 事件。

如果读取失败，App 会显示错误，不会继续保留旧额度。
本地测试时可以设置 `CODEX_QUOTA_USE_FALLBACK=1`，读取 fallback JSON：`~/Library/Application Support/CodexQuotaTouchBar/quota.json`。

## Touch Bar 自定义

在 App 内点击 `自定义 Touch Bar`，可以打开该 App 自己的 Touch Bar 自定义面板。

不要去 macOS 的 Control Strip 自定义界面里找这个项目。Apple 把系统 Control Strip 项目和每个 App 自己的 Touch Bar 项目分开管理。
