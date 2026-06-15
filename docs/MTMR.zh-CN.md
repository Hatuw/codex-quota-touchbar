# MTMR 设置

[English](MTMR.md) | [中文](MTMR.zh-CN.md)

MTMR 是推荐方案，因为它可以在你使用其他 macOS App 时，让额度组件继续显示在 Touch Bar 上。

## 安装

1. 从 MTMR 项目页安装 MTMR：https://github.com/toxblh/MTMR
2. 先打开一次 MTMR。
3. 在本仓库目录中运行：

   ```bash
   ./scripts/install_mtmr_config.sh
   ```

4. 重启 MTMR：

   ```bash
   pkill -x MTMR || true
   open -a /Applications/MTMR.app
   ```

## 安装脚本做了什么

安装脚本会：

1. 读取 `mtmr/items.template.json`。
2. 把 `__CODEX_QUOTA_COMMAND__` 和 `__CODEX_QUOTA_SCRIPT_PATH__` 替换成本地 helper 脚本路径。
3. 备份已有的 MTMR 配置。
4. 写入 `~/Library/Application Support/MTMR/items.json`。

## 当前组件格式

```text
5h ▬▬▬▬▬▬▬▬ 99% 19:36 | 周 ▬▬▬▬▬▬▬▬ 26% 6/11 09:02  ↻
```

第一个额度是 5 小时窗口，第二个额度是周窗口。
中文 locale 会显示 `周`，其他 locale 会显示 `W`。
如果想强制指定 label，可以在 inline command 中设置 `CODEX_QUOTA_WEEK_LABEL`。

`↻` 按钮会在后台重启 MTMR，让额度组件立刻重绘，不用等待下一次 1 分钟自动刷新。

## 数据来源

helper 默认会从本地 Codex app-server 读取 `account/rateLimits/read`。
这个数据通常比 session 日志更新，也更接近 Codex Desktop 自己显示的额度。

5 小时额度默认使用 Codex 主 `rateLimits` 返回里的账号 primary 额度。
周额度默认使用 Codex 主 `rateLimits` 返回里的账号 secondary 额度。

如果 app-server 不可用，helper 默认会显示错误，不会继续保留或复用旧额度。
你可以用 `CODEX_QUOTA_SOURCE=sessions` 强制扫描本地 Codex session 文件，或用 `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1` 显式允许它作为兜底。
如果没有找到匹配的额度数据，组件会显示错误，不会继续保留旧额度。

如果需要调整数据源或额度池，可以在 inline command 中设置：

- `CODEX_QUOTA_SOURCE=app-server`：只使用 app-server。
- `CODEX_QUOTA_SOURCE=sessions`：强制扫描 session 日志。
- `CODEX_QUOTA_PRIMARY_LIMIT_ID=...`：指定 5 小时额度池。
- `CODEX_QUOTA_WEEKLY_LIMIT_ID=...`：指定周额度池。
- `CODEX_QUOTA_LIMIT_ID=...`：旧版兼容配置，会同时覆盖两个额度窗口。
- `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1`：app-server 失败时才允许使用 session 日志兜底。
- `CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS=30`：调整读取 app-server 的等待秒数。
- `CODEX_QUOTA_APP_SERVER_ATTEMPTS=2`：重试瞬时 app-server 失败。
- `CODEX_QUOTA_APP_SERVER_RETRY_DELAY_SECONDS=3`：调整重试间隔。

只有明确想用 fallback JSON 测试时，才建议设置 `CODEX_QUOTA_USE_FALLBACK=1`。

## 调整样式

打开 `mtmr/items.template.json`，可以调整：

- `width`：MTMR 按钮宽度。
- `refreshInterval`：刷新间隔，单位是秒。

如果想修改血条长度，可以在 inline command 里设置 `CODEX_QUOTA_BAR_SLOTS`：

```json
{
  "source": {
    "inline": "CODEX_QUOTA_BAR_SLOTS=10 /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

修改模板后重新运行：

```bash
./scripts/install_mtmr_config.sh
```
