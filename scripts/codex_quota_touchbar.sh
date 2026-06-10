#!/bin/zsh
set -u

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Codex Quota TouchBar helper

Reads Codex local session JSONL files and prints quota text for MTMR or a terminal.

Usage:
  scripts/codex_quota_touchbar.sh [mode]

Modes:
  compact-bar        Single-line MTMR display with colored bars.
  primary-bar        Five-hour quota with a colored bar.
  weekly-bar         Weekly quota with a colored bar.
  primary            Five-hour quota without a bar.
  weekly             Weekly quota without a bar.
  compact            Single-line plain text without bars.
  multiline          Default two-line plain text output.

Environment:
  CODEX_SESSIONS_DIR       Codex sessions directory. Default: ~/.codex/sessions
  CODEX_QUOTA_FILE         Fallback JSON file. Default: ~/Library/Application Support/CodexQuotaTouchBar/quota.json
  CODEX_QUOTA_LIMIT_ID     Rate limit id to read. Default: codex. Use * to accept all.
  CODEX_QUOTA_LOCALE       Locale hint for labels. Default: system locale.
  CODEX_QUOTA_WEEK_LABEL   Weekly quota label override. Default: localized Chinese label for Chinese locales, W otherwise.
  CODEX_QUOTA_BAR_SLOTS    Bar length for compact-bar. Default: 8
  CODEX_QUOTA_DEBUG=1      Log refreshes to ~/Library/Logs/CodexQuotaTouchBar/mtmr-refresh.log
USAGE
  exit 0
fi

QUOTA_FILE="${CODEX_QUOTA_FILE:-$HOME/Library/Application Support/CodexQuotaTouchBar/quota.json}"
CODEX_SESSIONS_DIR="${CODEX_SESSIONS_DIR:-$HOME/.codex/sessions}"
DISPLAY_MODE="${1:-multiline}"

/usr/bin/python3 - "$CODEX_SESSIONS_DIR" "$QUOTA_FILE" "$DISPLAY_MODE" <<'PY'
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import json
import os
import re
import subprocess
import sys


sessions_dir = Path(sys.argv[1]).expanduser()
quota_file = Path(sys.argv[2]).expanduser()
display_mode = sys.argv[3] if len(sys.argv) > 3 else "multiline"

ANSI_RESET = "\033[0m"
ANSI_GRAY = "\033[90m"
ANSI_GREEN = "\033[92m"
ANSI_YELLOW = "\033[93m"
ANSI_RED = "\033[91m"


def emit(text: str) -> None:
    print(text)

    if os.environ.get("CODEX_QUOTA_DEBUG") != "1":
        return

    debug_log = Path(os.environ.get("CODEX_QUOTA_DEBUG_LOG", "~/Library/Logs/CodexQuotaTouchBar/mtmr-refresh.log")).expanduser()
    try:
        debug_log.parent.mkdir(parents=True, exist_ok=True)
        now = datetime.now().astimezone().isoformat(timespec="seconds")
        with debug_log.open("a", encoding="utf-8") as handle:
            handle.write(f"{now}\t{display_mode}\t{text}\n")
    except Exception:
        pass


def parse_date(raw: str | None) -> datetime | None:
    if not raw:
        return None

    try:
        normalized = raw[:-1] + "+00:00" if raw.endswith("Z") else raw
        return datetime.fromisoformat(normalized).astimezone()
    except Exception:
        return None


def format_time(value: datetime | None) -> str:
    if value is None:
        return "--:--"

    now = datetime.now().astimezone()
    if value.date() == now.date():
        return value.strftime("%H:%M")
    return value.strftime("%m/%d %H:%M")


def format_time_compact(value: datetime | None) -> str:
    if value is None:
        return "--:--"

    now = datetime.now().astimezone()
    if value.date() == now.date():
        return value.strftime("%H:%M")
    return f"{value.month}/{value.day} {value.strftime('%H:%M')}"


def round_percent(value: object) -> str:
    try:
        number = max(0.0, min(100.0, float(value)))
        return str(int(round(number)))
    except Exception:
        return "--"


def percent_number(value: object) -> float | None:
    try:
        return max(0.0, min(100.0, float(value)))
    except Exception:
        return None


def quota_color(value: object) -> str:
    number = percent_number(value)
    if number is None:
        return ANSI_GRAY
    if number >= 60:
        return ANSI_GREEN
    if number >= 30:
        return ANSI_YELLOW
    return ANSI_RED


def colored_percent(value: object) -> str:
    return f"{quota_color(value)}{round_percent(value)}%{ANSI_RESET}"


def colored_label(label: str, value: object) -> str:
    return f"{quota_color(value)}{label}{ANSI_RESET}"


def first_locale(raw: str | None) -> str | None:
    if not raw:
        return None

    for candidate in re.split(r"[:,;\s()\"']+", raw.strip()):
        if re.match(r"^[A-Za-z]{2,3}([_-][A-Za-z0-9]+)*", candidate):
            return candidate
    return None


def macos_default(key: str) -> str | None:
    try:
        result = subprocess.run(
            ["/usr/bin/defaults", "read", "-g", key],
            check=False,
            capture_output=True,
            text=True,
            timeout=1,
        )
    except Exception:
        return None

    if result.returncode != 0:
        return None

    return result.stdout.strip()


def locale_hint() -> str | None:
    sources = [
        os.environ.get("CODEX_QUOTA_LOCALE"),
        macos_default("AppleLocale"),
        macos_default("AppleLanguages"),
        os.environ.get("LC_ALL"),
        os.environ.get("LC_MESSAGES"),
        os.environ.get("LANG"),
        os.environ.get("LANGUAGE"),
    ]

    for source in sources:
        candidate = first_locale(source)
        if candidate:
            return candidate
    return None


def uses_chinese_label() -> bool:
    candidate = locale_hint()
    if not candidate:
        return False

    normalized = candidate.lower().replace("-", "_")
    return normalized == "zh" or normalized.startswith("zh_") or normalized.startswith("zh.")


def weekly_label() -> str:
    override = os.environ.get("CODEX_QUOTA_WEEK_LABEL")
    if override is not None and override.strip():
        return override.strip()

    return "周" if uses_chinese_label() else "W"


def progress_bar(value: object, slots: int = 10, cell: str = "▬") -> str:
    number = percent_number(value)
    if number is None:
        return f"{ANSI_GRAY}{cell * slots}{ANSI_RESET}"

    filled_cells = int(round(number / 100 * slots))
    filled_text = cell * filled_cells
    empty_cells = slots - filled_cells
    empty_text = cell * max(0, empty_cells)
    return f"{quota_color(number)}{filled_text}{ANSI_GRAY}{empty_text}{ANSI_RESET}"


def compact_bar_slots() -> int:
    try:
        return max(3, min(30, int(os.environ.get("CODEX_QUOTA_BAR_SLOTS", "8"))))
    except Exception:
        return 8


def accepted_limit_ids() -> set[str] | None:
    raw = os.environ.get("CODEX_QUOTA_LIMIT_ID", "codex").strip()
    if raw in {"", "*", "all"}:
        return None

    return {part.strip() for part in raw.split(",") if part.strip()}


ACCEPTED_LIMIT_IDS = accepted_limit_ids()


def accepts_rate_limit(raw: object) -> bool:
    if ACCEPTED_LIMIT_IDS is None:
        return True
    if not isinstance(raw, dict):
        return False

    limit_id = raw.get("limit_id")
    return isinstance(limit_id, str) and limit_id in ACCEPTED_LIMIT_IDS


def rate_window(raw: object) -> tuple[float, datetime] | None:
    if not isinstance(raw, dict):
        return None

    try:
        used_percent = float(raw["used_percent"])
        resets_at = datetime.fromtimestamp(float(raw["resets_at"]), tz=timezone.utc).astimezone()
        return max(0.0, min(100.0, 100.0 - used_percent)), resets_at
    except Exception:
        return None


def latest_codex_rate_limits() -> tuple[float, datetime, float, datetime] | None:
    if not sessions_dir.exists():
        return None

    files = []
    for path in sessions_dir.rglob("*.jsonl"):
        try:
            files.append((path.stat().st_mtime, path))
        except OSError:
            continue

    files.sort(reverse=True)

    best_seen_at: datetime | None = None
    best_value: tuple[float, datetime, float, datetime] | None = None

    for modified_at, path in files[:80]:
        if best_seen_at is not None:
            file_time = datetime.fromtimestamp(modified_at, tz=timezone.utc).astimezone()
            if file_time < best_seen_at:
                break

        try:
            size = path.stat().st_size
            start = max(0, size - 2 * 1024 * 1024)
            with path.open("rb") as handle:
                handle.seek(start)
                raw = handle.read().decode("utf-8", errors="ignore")
            lines = raw.splitlines()
            if start > 0 and lines:
                lines = lines[1:]
        except OSError:
            continue

        for line in reversed(lines):
            if '"rate_limits"' not in line:
                continue

            try:
                event = json.loads(line)
                payload = event.get("payload", {})
                limits = payload.get("rate_limits", {})
                if not accepts_rate_limit(limits):
                    continue
                primary = rate_window(limits.get("primary"))
                secondary = rate_window(limits.get("secondary"))
                seen_at = parse_date(event.get("timestamp"))
            except Exception:
                continue

            if primary is None or secondary is None or seen_at is None:
                continue

            if best_seen_at is None or seen_at > best_seen_at:
                best_seen_at = seen_at
                best_value = (primary[0], primary[1], secondary[0], secondary[1])

            break

    return best_value


def local_quota_fallback() -> tuple[float | None, datetime | None, float | None, datetime | None]:
    if not quota_file.exists():
        return None, None, None, None

    try:
        payload = json.loads(quota_file.read_text(encoding="utf-8"))
    except Exception:
        return None, None, None, None

    legacy_percent = payload.get("remainingPercent", payload.get("remaining_percent"))
    five_hour = payload.get("fiveHourRemainingPercent", payload.get("five_hour_remaining_percent", legacy_percent))
    weekly = payload.get("weeklyRemainingPercent", payload.get("weekly_remaining_percent", legacy_percent))
    shared_time = payload.get("refreshedAt", payload.get("refreshed_at", payload.get("updatedAt", payload.get("updated_at"))))
    five_hour_time = payload.get("fiveHourResetAt", payload.get("five_hour_reset_at", payload.get("fiveHourRefreshedAt", payload.get("five_hour_refreshed_at", shared_time))))
    weekly_time = payload.get("weeklyResetAt", payload.get("weekly_reset_at", payload.get("weeklyRefreshedAt", payload.get("weekly_refreshed_at", shared_time))))

    return (
        None if five_hour is None else float(five_hour),
        parse_date(five_hour_time),
        None if weekly is None else float(weekly),
        parse_date(weekly_time),
    )


real = latest_codex_rate_limits()
if real is not None:
    five_hour, five_hour_reset, weekly, weekly_reset = real
else:
    five_hour, five_hour_reset, weekly, weekly_reset = local_quota_fallback()

weekly_quota_label = weekly_label()

primary_text = f"5h {colored_percent(five_hour)} {format_time(five_hour_reset)}"
weekly_text = f"{weekly_quota_label} {colored_percent(weekly)} {format_time(weekly_reset)}"
bar_slots = compact_bar_slots()
primary_bar_text = f"5h {progress_bar(five_hour)} {colored_percent(five_hour)} {format_time(five_hour_reset)}"
weekly_bar_text = f"{weekly_quota_label} {progress_bar(weekly)} {colored_percent(weekly)} {format_time(weekly_reset)}"
compact_bar_text = (
    f"{colored_label('5h', five_hour)} {progress_bar(five_hour, bar_slots)} {colored_percent(five_hour)} {format_time_compact(five_hour_reset)} "
    f"{ANSI_GRAY}|{ANSI_RESET} "
    f"{colored_label(weekly_quota_label, weekly)} {progress_bar(weekly, bar_slots)} {colored_percent(weekly)} {format_time_compact(weekly_reset)}"
)

if display_mode in {"primary", "5h", "five-hour"}:
    emit(primary_text)
elif display_mode in {"secondary", "week", "weekly"}:
    emit(weekly_text)
elif display_mode in {"primary-bar", "5h-bar", "five-hour-bar"}:
    emit(primary_bar_text)
elif display_mode in {"secondary-bar", "week-bar", "weekly-bar"}:
    emit(weekly_bar_text)
elif display_mode in {"compact-bar", "horizontal-bar"}:
    emit(compact_bar_text)
elif display_mode == "compact":
    emit(f"{primary_text} | {weekly_text}")
else:
    emit(f"{primary_text}\n{weekly_text}")
PY
