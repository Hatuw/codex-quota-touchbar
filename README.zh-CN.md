# Codex Quota TouchBar

[English](README.md) | [中文](README.zh-CN.md)

把 Codex 剩余额度显示在 Mac Touch Bar 上。

`Codex Quota TouchBar` 会读取本地 Codex session 日志，提取最新的 `rate_limits`，并通过一个紧凑的 MTMR Touch Bar 组件展示 5 小时额度和周额度。

> 这是非官方社区项目，与 OpenAI 官方无关。

## 预览

默认 MTMR 组件是一行紧凑显示：

```text
5h ▬▬▬▬▬▬▬▬ 99% 19:36 | 周 ▬▬▬▬▬▬▬▬ 26% 6/11 09:02  ↻
```

在 MTMR 中会自动上色：

- 绿色：剩余额度 `60%` 及以上。
- 黄色：剩余额度 `30%` 到 `59%`。
- 红色：剩余额度低于 `30%`。
- 灰色：血条空值部分。

## 环境要求

- 带 Touch Bar 的 macOS。
- [MTMR](https://github.com/toxblh/MTMR)，用于常驻 Touch Bar 显示。
- 本地 Codex session 文件，默认位于 `~/.codex/sessions`。
- Python 3，现代 macOS 通常自带 `/usr/bin/python3`。

本仓库也包含一个可选的原生 macOS App。它可以显示真正的 AppKit 进度条，但 Apple 只允许普通 App 在“当前 App 激活”时控制 Touch Bar。如果你希望全局常驻显示，请使用 MTMR 方案。

## 快速开始

1. 安装并打开 MTMR。

2. 克隆本项目：

   ```bash
   git clone https://github.com/Hatuw/codex-quota-touchbar.git
   cd codex-quota-touchbar
   ```

3. 安装 MTMR 配置：

   ```bash
   ./scripts/install_mtmr_config.sh
   ```

4. 重启 MTMR：

   ```bash
   pkill -x MTMR || true
   open -a /Applications/MTMR.app
   ```

安装脚本会先备份你已有的 MTMR 配置，再写入新配置。

## 工作原理

Codex session 文件是 JSONL 格式。本项目会扫描最近的文件：

```text
~/.codex/sessions
```

脚本会寻找最新的 `payload.rate_limits` 事件，并且默认只接受 `rate_limits.limit_id` 为 `codex` 的记录。
这样可以避免附近其他 Codex session 里的实验额度池或模型专属额度池覆盖真实 Codex Pro 额度。

显示字段对应关系：

- `rate_limits.primary.used_percent` 对应 5 小时额度。
- `rate_limits.secondary.used_percent` 对应周额度。
- `resets_at` 对应显示的刷新/重置时间。

剩余额度计算方式：

```text
remaining = 100 - used_percent
```

如果没有找到 Codex 的 rate limit 记录，脚本会显示错误，不会继续显示旧额度。

只有本地测试时才建议显式开启 fallback JSON，设置 `CODEX_QUOTA_USE_FALLBACK=1` 后会读取：

```text
~/Library/Application Support/CodexQuotaTouchBar/quota.json
```

你可以把 [examples/quota.example.json](examples/quota.example.json) 复制到这个路径，用来本地测试。

## 自定义

MTMR 模板文件在这里：

```text
mtmr/items.template.json
```

常用配置：

- `refreshInterval`：默认 `600`，表示 10 分钟刷新一次。
- `width`：默认 `430`，表示 Touch Bar 按钮宽度。
- `CODEX_QUOTA_LIMIT_ID`：默认 `codex`，控制显示哪个 `rate_limits.limit_id`。设置为 `*` 时会接受所有 rate limit 记录。
- `CODEX_QUOTA_USE_FALLBACK`：默认关闭。设置为 `1` 时，如果没有真实 Codex 数据，会读取 `CODEX_QUOTA_FILE`。
- `CODEX_QUOTA_LOCALE`：可选，用来指定 label 判断用的 locale。默认读取系统 locale。
- `CODEX_QUOTA_WEEK_LABEL`：可选，用来强制指定周额度 label。默认中文 locale 显示 `周`，其他 locale 显示 `W`。
- `CODEX_QUOTA_BAR_SLOTS`：默认 `8`，控制血条长度。

例如把血条加长：

```json
{
  "source": {
    "inline": "CODEX_QUOTA_BAR_SLOTS=10 /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

例如指定额度池：

```json
{
  "source": {
    "inline": "CODEX_QUOTA_LIMIT_ID=codex /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

修改 `mtmr/items.template.json` 后，重新运行：

```bash
./scripts/install_mtmr_config.sh
```

更多 MTMR 说明：[docs/MTMR.zh-CN.md](docs/MTMR.zh-CN.md) / [English](docs/MTMR.md)。

## 辅助脚本

直接运行：

```bash
./scripts/codex_quota_touchbar.sh compact-bar
```

查看所有模式：

```bash
./scripts/codex_quota_touchbar.sh --help
```

常用环境变量：

```bash
CODEX_SESSIONS_DIR="$HOME/.codex/sessions"
CODEX_QUOTA_FILE="$HOME/Library/Application Support/CodexQuotaTouchBar/quota.json"
CODEX_QUOTA_LIMIT_ID=codex
CODEX_QUOTA_USE_FALLBACK=0
CODEX_QUOTA_LOCALE=zh_CN
CODEX_QUOTA_WEEK_LABEL=周
CODEX_QUOTA_BAR_SLOTS=8
CODEX_QUOTA_DEBUG=1
```

## 可选原生 App

构建可选的 AppKit App：

```bash
./scripts/build_app.sh
```

App 会输出到：

```text
outputs/CodexQuotaTouchBar.app
```

打开 App 并让窗口处于激活状态，就能看到它自己的 Touch Bar 项目。这个 App 适合实验真正的进度条，但不能跨所有 macOS App 常驻显示。

更多原生 App 说明：[docs/NATIVE_APP.zh-CN.md](docs/NATIVE_APP.zh-CN.md) / [English](docs/NATIVE_APP.md)。

## 开发

运行测试：

```bash
swift test
```

构建 release：

```bash
swift build -c release
```

验证 MTMR 模板：

```bash
python3 -m json.tool mtmr/items.template.json >/dev/null
```

## 故障排查

如果组件不更新：

- 确认 MTMR 正在运行：

  ```bash
  pgrep -fl MTMR
  ```

- 手动运行 helper：

  ```bash
  ./scripts/codex_quota_touchbar.sh compact-bar
  ```

- 打开刷新日志：

  ```bash
  CODEX_QUOTA_DEBUG=1 ./scripts/codex_quota_touchbar.sh compact-bar
  tail -f "$HOME/Library/Logs/CodexQuotaTouchBar/mtmr-refresh.log"
  ```

如果组件显示错误，说明 Codex 可能还没有写入最新的 `rate_limits` 事件。开始或继续一个 Codex session 后，点 `↻` 按钮，或重新运行 helper 检查。

## 限制

- 当前读取的是本地 Codex session 日志，不是官方额度 API。
- MTMR 方案是文本式 Touch Bar 组件，不是真正的 AppKit 进度条。
- 原生 AppKit Touch Bar 项目只有在该 App 激活时才会显示。

## License

MIT，见 [LICENSE](LICENSE)。
