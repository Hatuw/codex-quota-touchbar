# Codex Quota TouchBar

[English](README.md) | [中文](README.zh-CN.md)

Show your Codex quota on the Mac Touch Bar.

`Codex Quota TouchBar` reads local Codex session logs, extracts the latest `rate_limits`, and renders the 5-hour quota plus weekly quota in a compact MTMR Touch Bar widget.

> This is an unofficial community project. It is not affiliated with OpenAI.

## Preview

The default MTMR widget is a compact single-line display:

```text
5h ▬▬▬▬▬▬▬▬ 99% 19:36 | W ▬▬▬▬▬▬▬▬ 26% 6/11 09:02  ↻
```

Colors are applied in MTMR:

- Green: quota remaining is `60%` or higher.
- Yellow: quota remaining is between `30%` and `59%`.
- Red: quota remaining is lower than `30%`.
- Gray: empty part of the bar.

## Requirements

- macOS with a Touch Bar.
- [MTMR](https://github.com/toxblh/MTMR) for always-on Touch Bar display.
- Codex local session files under `~/.codex/sessions`.
- Python 3, available at `/usr/bin/python3` on modern macOS.

The native macOS app in this repository is optional. It can show a real AppKit progress bar, but Apple only allows normal apps to control the Touch Bar while that app is active. For always-on display, use MTMR.

## Quick Start

1. Install and open MTMR.

2. Clone this project:

   ```bash
   git clone https://github.com/Hatuw/codex-quota-touchbar.git
   cd codex-quota-touchbar
   ```

3. Install the MTMR config:

   ```bash
   ./scripts/install_mtmr_config.sh
   ```

4. Restart MTMR:

   ```bash
   pkill -x MTMR || true
   open -a /Applications/MTMR.app
   ```

The installer backs up your existing MTMR config before writing a new one.

## How It Works

Codex session files are JSONL files. This project scans the newest files under:

```text
~/.codex/sessions
```

It looks for the latest event with `payload.rate_limits` and `rate_limits.limit_id` set to `codex`.
This avoids mixing in other experimental or model-specific rate limit pools from nearby Codex sessions.

The display maps:

- `rate_limits.primary.used_percent` to the 5-hour quota.
- `rate_limits.secondary.used_percent` to the weekly quota.
- `resets_at` to the displayed reset time.

Displayed remaining quota is calculated as:

```text
remaining = 100 - used_percent
```

If no Codex rate limit event is found, the helper shows an error instead of keeping an old quota on screen.

For local testing only, you can opt into the fallback JSON file by setting `CODEX_QUOTA_USE_FALLBACK=1`:

```text
~/Library/Application Support/CodexQuotaTouchBar/quota.json
```

You can copy [examples/quota.example.json](examples/quota.example.json) to that path for local testing.

## Customize

The MTMR template lives here:

```text
mtmr/items.template.json
```

Useful settings:

- `refreshInterval`: default `600`, meaning 10 minutes.
- `width`: default `430`, the Touch Bar button width.
- `CODEX_QUOTA_LIMIT_ID`: default `codex`, controls which `rate_limits.limit_id` is displayed. Use `*` to accept all rate limit records.
- `CODEX_QUOTA_USE_FALLBACK`: default off. Set to `1` to read `CODEX_QUOTA_FILE` when no real Codex data is available.
- `CODEX_QUOTA_LOCALE`: optional locale hint for labels. By default, the helper reads the system locale.
- `CODEX_QUOTA_WEEK_LABEL`: optional weekly label override. By default, Chinese locales use the localized weekly label; other locales show `W`.
- `CODEX_QUOTA_BAR_SLOTS`: default `8`, controls bar length.

Example with a longer bar:

```json
{
  "source": {
    "inline": "CODEX_QUOTA_BAR_SLOTS=10 /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

Example with a custom limit id:

```json
{
  "source": {
    "inline": "CODEX_QUOTA_LIMIT_ID=codex /path/to/scripts/codex_quota_touchbar.sh compact-bar"
  }
}
```

If you edit `mtmr/items.template.json`, run the installer again:

```bash
./scripts/install_mtmr_config.sh
```

More MTMR details: [docs/MTMR.md](docs/MTMR.md) / [中文](docs/MTMR.zh-CN.md).

## Helper Script

Run the helper directly:

```bash
./scripts/codex_quota_touchbar.sh compact-bar
```

Show all modes:

```bash
./scripts/codex_quota_touchbar.sh --help
```

Useful environment variables:

```bash
CODEX_SESSIONS_DIR="$HOME/.codex/sessions"
CODEX_QUOTA_FILE="$HOME/Library/Application Support/CodexQuotaTouchBar/quota.json"
CODEX_QUOTA_LIMIT_ID=codex
CODEX_QUOTA_USE_FALLBACK=0
CODEX_QUOTA_LOCALE=en_US
CODEX_QUOTA_WEEK_LABEL=W
CODEX_QUOTA_BAR_SLOTS=8
CODEX_QUOTA_DEBUG=1
```

## Optional Native App

Build the optional AppKit app:

```bash
./scripts/build_app.sh
```

The app bundle is written to:

```text
outputs/CodexQuotaTouchBar.app
```

Open the app and make its window active to see its custom Touch Bar item. This app is useful for experimenting with real progress bars, but it cannot stay visible across all macOS apps.

More native app details: [docs/NATIVE_APP.md](docs/NATIVE_APP.md) / [中文](docs/NATIVE_APP.zh-CN.md).

## Development

Run tests:

```bash
swift test
```

Build a release binary:

```bash
swift build -c release
```

Validate the MTMR template:

```bash
python3 -m json.tool mtmr/items.template.json >/dev/null
```

## Troubleshooting

If the widget does not update:

- Confirm MTMR is running:

  ```bash
  pgrep -fl MTMR
  ```

- Run the helper manually:

  ```bash
  ./scripts/codex_quota_touchbar.sh compact-bar
  ```

- Enable refresh logging:

  ```bash
  CODEX_QUOTA_DEBUG=1 ./scripts/codex_quota_touchbar.sh compact-bar
  tail -f "$HOME/Library/Logs/CodexQuotaTouchBar/mtmr-refresh.log"
  ```

If the widget shows an error, Codex may not have written a recent `rate_limits` event yet. Start or continue a Codex session, tap the `↻` button, or run the helper again.

## Limitations

- This reads local Codex session logs; there is no official quota API integration.
- MTMR renders a text-based Touch Bar widget, not a native AppKit progress view.
- The native AppKit Touch Bar item only appears while the app is active.

## License

MIT. See [LICENSE](LICENSE).
