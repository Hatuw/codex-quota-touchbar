# MTMR Setup

[English](MTMR.md) | [中文](MTMR.zh-CN.md)

MTMR is the recommended way to keep the quota widget visible while you use other macOS apps.

## Install

1. Install MTMR from its project page: https://github.com/toxblh/MTMR
2. Open MTMR once.
3. From this repository, run:

   ```bash
   ./scripts/install_mtmr_config.sh
   ```

4. Restart MTMR:

   ```bash
   pkill -x MTMR || true
   open -a /Applications/MTMR.app
   ```

## What The Installer Does

The installer:

1. Reads `mtmr/items.template.json`.
2. Replaces `__CODEX_QUOTA_COMMAND__` and `__CODEX_QUOTA_SCRIPT_PATH__` with the local helper script path.
3. Backs up the existing MTMR config.
4. Writes `~/Library/Application Support/MTMR/items.json`.

## Current Widget Format

```text
5h ▬▬▬▬▬▬ 99% 19:36 | W ▬▬▬▬▬▬ 26% 6/11 09:02 🎟️×1  ↻
```

Accounts that only expose a single weekly window show:

```text
W ▬▬▬▬▬▬ 98% 7/20 05:21 🎟️×1  ↻
```

The first quota is the 5-hour window. The second quota is the weekly window.
Chinese locales use the localized weekly label. Other locales show it as `W`.
Set `CODEX_QUOTA_WEEK_LABEL` in the inline command to override that label.

The `↻` button restarts MTMR in the background so the quota widget redraws immediately instead of waiting for the next 1-minute interval.

## Data Source

The helper reads `account/rateLimits/read` from the local Codex app-server by default.
This usually matches the quota data shown by Codex Desktop more closely than session logs.
The helper automatically finds the CLI bundled with the current `ChatGPT.app` or the pre-merge `Codex.app`, including when MTMR runs with a minimal `PATH`.
The unified app selects a quota context from its launch origin. The helper supplies the desktop app's `Codex Desktop` context so MTMR does not accidentally read a separate CLI quota pool.

The helper classifies windows by duration: `300` minutes is the 5-hour quota and `10080` minutes is the weekly quota.
Legacy two-window responses continue to show both items. A new response with a 7-day `primary` and `secondary=null` shows the weekly quota alone.

If app-server is temporarily unavailable, the helper shows the last successful quota for short glitches.
After repeated failed refreshes, it shows an error instead of keeping stale data forever.
You can force local Codex session scanning with `CODEX_QUOTA_SOURCE=sessions`, or explicitly allow it as a fallback with `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1`.
If no matching quota data or last-success cache is found, the widget shows an error.

To tune the source or limit ids, set these variables in the inline command:

- `CODEX_QUOTA_SOURCE=app-server` to require app-server.
- `CODEX_QUOTA_SOURCE=sessions` to force session-log scanning.
- `CODEX_QUOTA_PRIMARY_LIMIT_ID=...` for the 5-hour quota.
- `CODEX_QUOTA_WEEKLY_LIMIT_ID=...` for the weekly quota.
- `CODEX_QUOTA_LIMIT_ID=...` as a legacy override for both quota windows.
- `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1` to allow session logs if app-server fails.
- `CODEX_CLI_PATH=...` to point at `Contents/Resources/codex` when the desktop app is installed in a custom location.
- `CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS=30` to tune the app-server read timeout.
- `CODEX_QUOTA_APP_SERVER_ATTEMPTS=2` to retry transient app-server failures.
- `CODEX_QUOTA_APP_SERVER_RETRY_DELAY_SECONDS=3` to tune the retry delay.
- `CODEX_QUOTA_APP_SERVER_ORIGINATOR=...` only if a future desktop release changes its internal quota-context identifier.
- `CODEX_QUOTA_STALE_ERROR_THRESHOLD=3` to tune how many consecutive failed refreshes may use cached quota.

Set `CODEX_QUOTA_USE_FALLBACK=1` only when you intentionally want to test with the fallback JSON file.

## Tuning

Open `mtmr/items.template.json` and adjust:

- `width`: MTMR button width.
- `refreshInterval`: refresh interval in seconds.

To change bar length without editing Python code, set `CODEX_QUOTA_BAR_SLOTS` in the inline command:

```json
{
  "source": {
    "inline": "CODEX_QUOTA_BAR_SLOTS=10 /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

After editing the template, run:

```bash
./scripts/install_mtmr_config.sh
```
