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
2. Replaces `__CODEX_QUOTA_COMMAND__` with the local helper script path.
3. Backs up the existing MTMR config.
4. Writes `~/Library/Application Support/MTMR/items.json`.

## Current Widget Format

```text
5h ▬▬▬▬▬▬▬▬ 99% 19:36 | W ▬▬▬▬▬▬▬▬ 26% 6/11 09:02
```

The first quota is the 5-hour window. The second quota is the weekly window.
Chinese locales use the localized weekly label. Other locales show it as `W`.
Set `CODEX_QUOTA_WEEK_LABEL` in the inline command to override that label.

## Data Source

The helper scans local Codex session files and reads the newest `payload.rate_limits` event whose `rate_limits.limit_id` is `codex`.
This keeps model-specific or experimental limit pools from replacing the Codex Pro quota.

To read a different limit id, set `CODEX_QUOTA_LIMIT_ID` in the inline command. Use `*` to accept all rate limit records.

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
