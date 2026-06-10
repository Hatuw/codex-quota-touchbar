# Native App

[English](NATIVE_APP.md) | [中文](NATIVE_APP.zh-CN.md)

This repository also includes a small AppKit app.

The native app can render real rounded progress bars in Touch Bar, but it has one important macOS limitation: normal apps can only provide Touch Bar items while that app is active.

Use MTMR if you want the quota display to stay visible globally.

## Build

```bash
./scripts/build_app.sh
```

The app bundle is written to:

```text
outputs/CodexQuotaTouchBar.app
```

## Run

Open the generated app and click its window so it becomes the active app. Its custom Touch Bar item should appear.

The app reads the same data sources as the MTMR helper:

1. Latest Codex `rate_limits` event under `~/.codex/sessions`.
2. Fallback JSON at `~/Library/Application Support/CodexQuotaTouchBar/quota.json`.

## Touch Bar Customization

Inside the app, click `自定义 Touch Bar` to open the app-specific Touch Bar customization panel.

Do not look for this item in macOS Control Strip customization. Apple separates system Control Strip items from per-app Touch Bar items.
