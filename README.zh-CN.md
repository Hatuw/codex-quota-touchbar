# Codex Quota TouchBar

[English](README.md) | [中文](README.zh-CN.md)

把 Codex 剩余额度显示在 Mac Touch Bar 上。

`Codex Quota TouchBar` 会读取本地 Codex 额度数据，并通过一个紧凑的 MTMR Touch Bar 组件展示 5 小时额度和周额度。

> 这是非官方社区项目，与 OpenAI 官方无关。

## 预览

默认 MTMR 组件是一行紧凑显示：

```text
5h ▬▬▬▬▬▬ 99% 19:36 | 周 ▬▬▬▬▬▬ 26% 6/11 09:02 🎟️×1  ↻
```

在 MTMR 中会自动上色：

- 绿色：剩余额度 `60%` 及以上。
- 黄色：剩余额度 `30%` 到 `59%`。
- 红色：剩余额度低于 `30%`。
- 灰色：血条空值部分。

## 环境要求

- 带 Touch Bar 的 macOS。
- [MTMR](https://github.com/toxblh/MTMR)，用于常驻 Touch Bar 显示。
- 本地已安装带 Codex 功能的 ChatGPT Desktop、新版合并前的 Codex Desktop，或 Codex CLI。
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

默认情况下，helper 会向本地 Codex app-server 读取 `account/rateLimits/read`。
这个数据源比 session 日志更新，也更接近 Codex Desktop 内部使用的额度数据。
helper 会自动查找新版 `/Applications/ChatGPT.app` 和旧版 `/Applications/Codex.app` 内置的 Codex CLI，因此两种桌面应用都可以使用。
新版合并应用还会根据启动来源选择额度上下文。helper 默认以 `Codex Desktop` 上下文启动 app-server，确保 MTMR 与 ChatGPT/Codex Desktop 显示同一组额度，而不是误读另一组 CLI 额度池。

组件默认显示：

- 5 小时额度：Codex 主 `rateLimits` 返回里的账号 primary 额度。
- 周额度：Codex 主 `rateLimits` 返回里的账号 secondary 额度。
- 刷新/重置时间：分别来自对应额度窗口的 `resets_at`。
- 额度重置次数：来自 `rateLimitResetCredits.availableCount`，显示为 `🎟️×1`；它不是右侧 `↻` 手动刷新按钮的次数。

如果 Codex app-server 短暂不可用，helper 会先显示上一次成功读取的额度，避免偶发错误打断 Touch Bar。
如果连续多次刷新都失败，才会显示错误，避免一直保留过旧数据。
你仍然可以用 `CODEX_QUOTA_SOURCE=sessions` 强制扫描 session 日志，或用 `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1` 显式允许它作为兜底。
session 日志路径是：

```text
~/.codex/sessions
```

session 日志扫描会寻找最新的 `payload.rate_limits` 事件，并匹配对应的 `rate_limits.limit_id`。

剩余额度计算方式：

```text
remaining = 100 - used_percent
```

如果没有找到 Codex 的 rate limit 记录，也没有上一次成功缓存，脚本会显示错误。

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

- `refreshInterval`：默认 `60`，表示 1 分钟刷新一次。
- `width`：默认 `430`，表示 Touch Bar 按钮宽度。
- `CODEX_QUOTA_CACHE_FILE`：可选，用来指定最近一次成功额度的缓存路径。默认是 `~/Library/Application Support/CodexQuotaTouchBar/last-success.json`。
- `CODEX_QUOTA_SOURCE`：默认 `auto`。默认读取 Codex app-server，短暂失败时使用上一次成功额度。设置为 `sessions` 时强制扫描 session 日志。
- `CODEX_QUOTA_PRIMARY_LIMIT_ID`：可选，用来指定 5 小时额度池。默认使用账号 primary 额度。
- `CODEX_QUOTA_WEEKLY_LIMIT_ID`：可选，用来指定周额度池。默认使用账号 weekly 额度。
- `CODEX_QUOTA_LIMIT_ID`：旧版兼容配置，会同时覆盖 5 小时额度和周额度。只有你想让两个额度都来自同一个 limit id 时才建议使用。
- `CODEX_QUOTA_ALLOW_SESSION_FALLBACK`：默认关闭。设置为 `1` 后，app-server 暂时不可用时才会用 session 日志兜底。
- `CODEX_QUOTA_USE_FALLBACK`：默认关闭。设置为 `1` 时，如果没有真实 Codex 数据，会读取 `CODEX_QUOTA_FILE`。
- `CODEX_CLI_PATH`：可选，用来指定 Codex CLI 路径。默认依次查找 `PATH`、新版 `ChatGPT.app` 和旧版 `Codex.app`。
- `CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS`：默认 `30`，表示读取 app-server 的等待秒数。
- `CODEX_QUOTA_APP_SERVER_ATTEMPTS`：默认 `2`，表示显示错误前最多读取 app-server 的次数。
- `CODEX_QUOTA_APP_SERVER_RETRY_DELAY_SECONDS`：默认 `3`，表示两次 app-server 读取之间等待的秒数。
- `CODEX_QUOTA_APP_SERVER_ORIGINATOR`：默认 `Codex Desktop`，用于让 app-server 读取与桌面应用一致的额度上下文。仅在新版应用再次调整内部标识时才需要覆盖。
- `CODEX_QUOTA_STALE_ERROR_THRESHOLD`：默认 `3`，表示连续失败多少次后才显示错误，不再显示缓存额度。
- `CODEX_QUOTA_LOCALE`：可选，用来指定 label 判断用的 locale。默认读取系统 locale。
- `CODEX_QUOTA_WEEK_LABEL`：可选，用来强制指定周额度 label。默认中文 locale 显示 `周`，其他 locale 显示 `W`。
- `CODEX_QUOTA_BAR_SLOTS`：默认 `6`，控制血条长度。

例如把血条加长：

```json
{
  "source": {
    "inline": "CODEX_QUOTA_BAR_SLOTS=10 /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

例如强制使用 session 日志：

```json
{
  "source": {
    "inline": "CODEX_QUOTA_SOURCE=sessions /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

例如显式指定模型专属额度池：

```json
{
  "source": {
    "inline": "CODEX_QUOTA_PRIMARY_LIMIT_ID=codex_bengalfox CODEX_QUOTA_WEEKLY_LIMIT_ID=codex /path/to/scripts/codex_quota_touchbar.sh compact-bar"
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
CODEX_QUOTA_CACHE_FILE="$HOME/Library/Application Support/CodexQuotaTouchBar/last-success.json"
CODEX_QUOTA_SOURCE=auto
CODEX_QUOTA_PRIMARY_LIMIT_ID=auto
CODEX_QUOTA_WEEKLY_LIMIT_ID=codex
CODEX_QUOTA_ALLOW_SESSION_FALLBACK=0
CODEX_QUOTA_USE_FALLBACK=0
CODEX_CLI_PATH=/Applications/ChatGPT.app/Contents/Resources/codex
CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS=30
CODEX_QUOTA_APP_SERVER_ATTEMPTS=2
CODEX_QUOTA_APP_SERVER_RETRY_DELAY_SECONDS=3
CODEX_QUOTA_APP_SERVER_ORIGINATOR="Codex Desktop"
CODEX_QUOTA_STALE_ERROR_THRESHOLD=3
CODEX_QUOTA_LOCALE=zh_CN
CODEX_QUOTA_WEEK_LABEL=周
CODEX_QUOTA_BAR_SLOTS=6
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

  读取失败和重试详情即使没有开启 `CODEX_QUOTA_DEBUG`，也会写入同一个日志路径。

如果组件显示错误，通常表示 Codex app-server 已经连续多次失败，或没有返回可用的额度数据。开始或继续一个 Codex session 后，点 `↻` 按钮，或重新运行 helper 检查。

如果 ChatGPT/Codex Desktop 安装在自定义位置，可以通过 `CODEX_CLI_PATH` 指向应用内的 `Contents/Resources/codex`。合并更新前的默认路径仍受支持：`/Applications/Codex.app/Contents/Resources/codex`。

## 限制

- 当前默认读取 Codex 本地 app-server。session 日志只作为显式开启的兜底；它不会直接调用公开的官方额度 API。
- MTMR 方案是文本式 Touch Bar 组件，不是真正的 AppKit 进度条。
- 原生 AppKit Touch Bar 项目只有在该 App 激活时才会显示。

## License

MIT，见 [LICENSE](LICENSE)。
