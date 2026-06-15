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
5h ▬▬▬▬▬▬▬▬ 99% 19:36 | W ▬▬▬▬▬▬▬▬ 26% 6/11 09:02  ↻
```

The first quota is the 5-hour window. The second quota is the weekly window.
Chinese locales use the localized weekly label. Other locales show it as `W`.
Set `CODEX_QUOTA_WEEK_LABEL` in the inline command to override that label.

The `↻` button restarts MTMR in the background so the quota widget redraws immediately instead of waiting for the next 10-minute interval.

## Data Source

The helper reads `account/rateLimits/read` from the local Codex app-server by default.
This usually matches the quota data shown by Codex Desktop more closely than session logs.

The 5-hour quota uses the account primary quota from Codex's main `rateLimits` response.
The weekly quota uses the account secondary quota from Codex's main `rateLimits` response.

If app-server is unavailable, the helper shows an error by default instead of keeping or reusing old quota data.
You can force local Codex session scanning with `CODEX_QUOTA_SOURCE=sessions`, or explicitly allow it as a fallback with `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1`.
If no matching quota data is found, the widget shows an error rather than keeping an old value on screen.

To tune the source or limit ids, set these variables in the inline command:

- `CODEX_QUOTA_SOURCE=app-server` to require app-server.
- `CODEX_QUOTA_SOURCE=sessions` to force session-log scanning.
- `CODEX_QUOTA_PRIMARY_LIMIT_ID=...` for the 5-hour quota.
- `CODEX_QUOTA_WEEKLY_LIMIT_ID=...` for the weekly quota.
- `CODEX_QUOTA_LIMIT_ID=...` as a legacy override for both quota windows.
- `CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1` to allow session logs if app-server fails.
- `CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS=30` to tune the app-server read timeout.

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
