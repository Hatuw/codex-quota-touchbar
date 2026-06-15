#!/bin/zsh
set -u

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<'USAGE'
Codex Quota TouchBar helper

Reads Codex local quota data and prints quota text for MTMR or a terminal.

Usage:
  scripts/codex_quota_touchbar.sh [mode]

Modes:
  compact-bar        Single-line MTMR display with colored bars.
  primary-bar        Five-hour quota with a colored bar.
  weekly-bar         Weekly quota with a colored bar.
  primary            Five-hour quota without a bar.
  weekly             Weekly quota without a bar.
  compact            Single-line plain text without bars.
  refresh-mtmr       Restart MTMR so the Touch Bar widget redraws immediately.
  multiline          Default two-line plain text output.

Environment:
  CODEX_SESSIONS_DIR       Codex sessions directory. Default: ~/.codex/sessions
  CODEX_QUOTA_FILE         Fallback JSON file. Default: ~/Library/Application Support/CodexQuotaTouchBar/quota.json
  CODEX_QUOTA_CACHE_FILE   Last successful real quota cache. Default: ~/Library/Application Support/CodexQuotaTouchBar/last-success.json
  CODEX_QUOTA_SOURCE       auto, app-server, or sessions. Default: auto
  CODEX_QUOTA_LIMIT_ID     Legacy limit id override for both quota windows.
  CODEX_QUOTA_PRIMARY_LIMIT_ID
                           Limit id for the 5-hour quota. Default: account primary quota.
  CODEX_QUOTA_WEEKLY_LIMIT_ID
                           Limit id for the weekly quota. Default: account weekly quota.
  CODEX_QUOTA_ALLOW_SESSION_FALLBACK=1
                           Fall back to session logs if app-server fails. Default: off.
  CODEX_QUOTA_USE_FALLBACK=1
                           Read CODEX_QUOTA_FILE when no real Codex data is available.
  CODEX_CLI_PATH           Codex CLI path. Default: PATH lookup, then /Applications/Codex.app/Contents/Resources/codex
  CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS
                           App-server read timeout. Default: 30
  CODEX_QUOTA_APP_SERVER_ATTEMPTS
                           App-server read attempts. Default: 2
  CODEX_QUOTA_APP_SERVER_RETRY_DELAY_SECONDS
                           Delay before retrying app-server reads. Default: 3
  CODEX_QUOTA_STALE_ERROR_THRESHOLD
                           Consecutive failed refreshes before showing an error. Default: 3
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
import selectors
import shutil
import subprocess
import sys
import time


sessions_dir = Path(sys.argv[1]).expanduser()
quota_file = Path(sys.argv[2]).expanduser()
cache_file = Path(os.environ.get("CODEX_QUOTA_CACHE_FILE", "~/Library/Application Support/CodexQuotaTouchBar/last-success.json")).expanduser()
display_mode = sys.argv[3] if len(sys.argv) > 3 else "multiline"

ANSI_RESET = "\033[0m"
ANSI_GRAY = "\033[90m"
ANSI_GREEN = "\033[92m"
ANSI_YELLOW = "\033[93m"
ANSI_RED = "\033[91m"


class QuotaReadError(Exception):
    pass


def log_line(kind: str, message: str) -> None:
    log_path = Path(os.environ.get("CODEX_QUOTA_DEBUG_LOG", "~/Library/Logs/CodexQuotaTouchBar/mtmr-refresh.log")).expanduser()
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        now = datetime.now().astimezone().isoformat(timespec="seconds")
        cleaned = " ".join(str(message).splitlines())
        with log_path.open("a", encoding="utf-8") as handle:
            handle.write(f"{now}\t{display_mode}\t{kind}\t{cleaned}\n")
    except Exception:
        pass


def emit(text: str) -> None:
    print(text)

    if os.environ.get("CODEX_QUOTA_DEBUG") != "1":
        return

    log_line("output", text)


def localized(chinese: str, english: str) -> str:
    return chinese if uses_chinese_label() else english


def emit_error(message: str) -> None:
    log_line("error", message)
    title = localized("⚠ 额度读取失败", "⚠ quota error")
    compact_modes = {"compact-bar", "horizontal-bar", "compact"}
    if display_mode in compact_modes:
        emit(f"{ANSI_RED}{title}{ANSI_RESET}")
    else:
        emit(f"{ANSI_RED}{title}{ANSI_RESET}\n{message}")


def parse_date(raw: str | None) -> datetime | None:
    if not raw:
        return None

    try:
        normalized = raw[:-1] + "+00:00" if raw.endswith("Z") else raw
        return datetime.fromisoformat(normalized).astimezone()
    except Exception:
        return None


def date_to_text(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone().isoformat(timespec="seconds")


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
SESSION_SCAN_MAX_BYTES = 64 * 1024 * 1024
SESSION_SCAN_CHUNK_BYTES = 1024 * 1024
try:
    APP_SERVER_TIMEOUT_SECONDS = max(
        2.0,
        min(60.0, float(os.environ.get("CODEX_QUOTA_APP_SERVER_TIMEOUT_SECONDS", "30"))),
    )
except Exception:
    APP_SERVER_TIMEOUT_SECONDS = 30.0
try:
    APP_SERVER_ATTEMPTS = max(1, min(5, int(os.environ.get("CODEX_QUOTA_APP_SERVER_ATTEMPTS", "2"))))
except Exception:
    APP_SERVER_ATTEMPTS = 2
try:
    APP_SERVER_RETRY_DELAY_SECONDS = max(
        0.0,
        min(30.0, float(os.environ.get("CODEX_QUOTA_APP_SERVER_RETRY_DELAY_SECONDS", "3"))),
    )
except Exception:
    APP_SERVER_RETRY_DELAY_SECONDS = 3.0
try:
    STALE_ERROR_THRESHOLD = max(1, min(60, int(os.environ.get("CODEX_QUOTA_STALE_ERROR_THRESHOLD", "3"))))
except Exception:
    STALE_ERROR_THRESHOLD = 3


def accepts_rate_limit(raw: object) -> bool:
    if ACCEPTED_LIMIT_IDS is None:
        return True
    if not isinstance(raw, dict):
        return False

    limit_id = raw.get("limit_id", raw.get("limitId"))
    return isinstance(limit_id, str) and limit_id in ACCEPTED_LIMIT_IDS


def rate_window(raw: object) -> tuple[float, datetime] | None:
    if not isinstance(raw, dict):
        return None

    try:
        used_percent = float(raw.get("used_percent", raw.get("usedPercent")))
        resets_at_raw = raw.get("resets_at", raw.get("resetsAt"))
        resets_at = datetime.fromtimestamp(float(resets_at_raw), tz=timezone.utc).astimezone()
        return max(0.0, min(100.0, 100.0 - used_percent)), resets_at
    except Exception:
        return None


def limit_id_of(snapshot: object) -> str | None:
    if not isinstance(snapshot, dict):
        return None
    raw = snapshot.get("limit_id", snapshot.get("limitId"))
    return raw if isinstance(raw, str) and raw else None


def legacy_limit_id_override() -> str | None:
    if "CODEX_QUOTA_LIMIT_ID" not in os.environ:
        return None

    raw = os.environ.get("CODEX_QUOTA_LIMIT_ID", "").strip()
    if raw in {"", "*", "all", "auto"}:
        return None
    if "," in raw:
        return None
    return raw


def configured_limit_id(env_name: str) -> str | None:
    raw = os.environ.get(env_name)
    if raw is None:
        return None

    value = raw.strip()
    if value in {"", "*", "all", "auto"}:
        return None
    return value


def env_flag(env_name: str) -> bool:
    return os.environ.get(env_name, "").strip().lower() in {"1", "true", "yes", "on"}


def codex_executable() -> str:
    configured = os.environ.get("CODEX_CLI_PATH")
    if configured and os.access(configured, os.X_OK):
        return configured

    found = shutil.which("codex")
    if found:
        return found

    bundled = "/Applications/Codex.app/Contents/Resources/codex"
    if os.access(bundled, os.X_OK):
        return bundled

    raise QuotaReadError("Cannot find Codex CLI. Set CODEX_CLI_PATH if Codex is installed elsewhere.")


def app_server_request(method: str, params: object = None) -> dict:
    errors: list[str] = []
    for attempt in range(1, APP_SERVER_ATTEMPTS + 1):
        try:
            return app_server_request_once(method, params)
        except QuotaReadError as error:
            message = str(error)
            errors.append(message)
            if attempt >= APP_SERVER_ATTEMPTS:
                break
            log_line("retry", f"Codex app-server attempt {attempt}/{APP_SERVER_ATTEMPTS} failed: {message}")
            if APP_SERVER_RETRY_DELAY_SECONDS > 0:
                time.sleep(APP_SERVER_RETRY_DELAY_SECONDS)

    if len(errors) == 1:
        raise QuotaReadError(errors[0])
    summary = " | ".join(f"attempt {index + 1}: {error}" for index, error in enumerate(errors))
    raise QuotaReadError(f"Codex app-server failed after {APP_SERVER_ATTEMPTS} attempts: {summary}")


def app_server_request_once(method: str, params: object = None) -> dict:
    executable = codex_executable()
    try:
        process = subprocess.Popen(
            [executable, "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
        )
    except OSError as error:
        raise QuotaReadError(f"Cannot start Codex app-server: {error}") from error

    try:
        assert process.stdin is not None
        assert process.stdout is not None
        assert process.stderr is not None

        requests = [
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {"name": "codex-quota-touchbar", "version": "0.1.0"},
                    "capabilities": None,
                },
            },
            {"id": 2, "method": method},
        ]
        if params is not None:
            requests[1]["params"] = params

        for request in requests:
            process.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
        process.stdin.flush()

        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ, "stdout")
        selector.register(process.stderr, selectors.EVENT_READ, "stderr")

        deadline = datetime.now().timestamp() + APP_SERVER_TIMEOUT_SECONDS
        errors: list[str] = []
        while datetime.now().timestamp() < deadline:
            timeout = max(0.1, deadline - datetime.now().timestamp())
            events = selector.select(timeout=timeout)
            if not events and process.poll() is not None:
                raise QuotaReadError(f"Codex app-server exited with status {process.returncode}")

            for key, _ in events:
                line = key.fileobj.readline()
                if not line:
                    if process.poll() is not None:
                        raise QuotaReadError(f"Codex app-server exited with status {process.returncode}")
                    continue

                if key.data == "stderr":
                    errors.append(line.strip())
                    continue

                try:
                    message = json.loads(line)
                except Exception:
                    continue

                if message.get("id") != 2:
                    continue
                if "error" in message:
                    raise QuotaReadError(f"Codex app-server returned an error: {message['error']}")
                result = message.get("result")
                if not isinstance(result, dict):
                    raise QuotaReadError("Codex app-server returned an invalid quota response")
                return result

        detail = f": {'; '.join(errors[-2:])}" if errors else ""
        raise QuotaReadError(f"Timed out reading Codex app-server quota{detail}")
    except (BrokenPipeError, OSError) as error:
        raise QuotaReadError(f"Cannot communicate with Codex app-server: {error}") from error
    finally:
        try:
            process.terminate()
            process.wait(timeout=1)
        except Exception:
            try:
                process.kill()
            except Exception:
                pass


def snapshot_by_limit_id(snapshots: list[dict], limit_id: str) -> dict | None:
    for snapshot in snapshots:
        if limit_id_of(snapshot) == limit_id:
            return snapshot
    return None


def app_server_rate_limits() -> tuple[float, datetime, float, datetime]:
    payload = app_server_request("account/rateLimits/read")
    default_snapshot = payload.get("rateLimits", payload.get("rate_limits"))
    by_limit_id = payload.get("rateLimitsByLimitId", payload.get("rate_limits_by_limit_id")) or {}

    snapshots: list[dict] = []
    if isinstance(default_snapshot, dict):
        snapshots.append(default_snapshot)
    if isinstance(by_limit_id, dict):
        for snapshot in by_limit_id.values():
            if isinstance(snapshot, dict) and snapshot not in snapshots:
                snapshots.append(snapshot)

    if not snapshots:
        raise QuotaReadError("Codex app-server returned no rate limit snapshots")

    account_snapshot = default_snapshot if isinstance(default_snapshot, dict) else snapshot_by_limit_id(snapshots, "codex")
    legacy_limit = legacy_limit_id_override()
    primary_limit_id = configured_limit_id("CODEX_QUOTA_PRIMARY_LIMIT_ID") or legacy_limit
    weekly_limit_id = configured_limit_id("CODEX_QUOTA_WEEKLY_LIMIT_ID") or legacy_limit

    primary_snapshot = snapshot_by_limit_id(snapshots, primary_limit_id) if primary_limit_id else account_snapshot
    weekly_snapshot = snapshot_by_limit_id(snapshots, weekly_limit_id) if weekly_limit_id else account_snapshot

    if primary_limit_id and primary_snapshot is None:
        raise QuotaReadError(f"Codex app-server quota response did not include limit id: {primary_limit_id}")
    if weekly_limit_id and weekly_snapshot is None:
        raise QuotaReadError(f"Codex app-server quota response did not include limit id: {weekly_limit_id}")

    if primary_snapshot is None or weekly_snapshot is None:
        raise QuotaReadError("Codex app-server quota response did not include usable snapshots")

    primary = rate_window(primary_snapshot.get("primary"))
    secondary = rate_window(weekly_snapshot.get("secondary"))
    if primary is None or secondary is None:
        raise QuotaReadError("Codex app-server quota response did not include both quota windows")

    return primary[0], primary[1], secondary[0], secondary[1]


def reversed_session_lines(path: Path):
    size = path.stat().st_size
    offset = size
    scanned = 0
    pending = b""

    with path.open("rb") as handle:
        while offset > 0 and scanned < SESSION_SCAN_MAX_BYTES:
            read_size = min(SESSION_SCAN_CHUNK_BYTES, offset, SESSION_SCAN_MAX_BYTES - scanned)
            if read_size <= 0:
                break

            offset -= read_size
            handle.seek(offset)
            chunk = handle.read(read_size)
            scanned += read_size

            data = chunk + pending
            lines = data.split(b"\n")
            if offset > 0:
                pending = lines[0]
                lines = lines[1:]
            else:
                pending = b""

            for raw_line in reversed(lines):
                line = raw_line.rstrip(b"\r").decode("utf-8", errors="ignore")
                if line:
                    yield line

        if pending:
            line = pending.rstrip(b"\r").decode("utf-8", errors="ignore")
            if line:
                yield line


def latest_codex_rate_limits() -> tuple[float, datetime, float, datetime] | None:
    if not sessions_dir.exists():
        raise QuotaReadError(f"Cannot find Codex sessions directory: {sessions_dir}")

    files = []
    for path in sessions_dir.rglob("*.jsonl"):
        try:
            files.append((path.stat().st_mtime, path))
        except OSError:
            continue

    files.sort(reverse=True)

    if not files:
        raise QuotaReadError(f"No Codex session JSONL files found under: {sessions_dir}")

    best_seen_at: datetime | None = None
    best_value: tuple[float, datetime, float, datetime] | None = None

    for modified_at, path in files[:80]:
        if best_seen_at is not None:
            file_time = datetime.fromtimestamp(modified_at, tz=timezone.utc).astimezone()
            if file_time < best_seen_at:
                break

        try:
            lines = reversed_session_lines(path)
        except OSError:
            continue

        for line in lines:
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

    if best_value is None:
        accepted = "*" if ACCEPTED_LIMIT_IDS is None else ",".join(sorted(ACCEPTED_LIMIT_IDS))
        raise QuotaReadError(f"No matching Codex rate limit event found for limit_id={accepted}")

    return best_value


def current_codex_rate_limits() -> tuple[float, datetime, float, datetime]:
    source = os.environ.get("CODEX_QUOTA_SOURCE", "auto").strip().lower()

    if source in {"session", "sessions", "logs", "jsonl"}:
        return latest_codex_rate_limits()

    if source in {"app", "app-server", "app_server"}:
        return app_server_rate_limits()

    if source not in {"", "auto"}:
        raise QuotaReadError(f"Unsupported CODEX_QUOTA_SOURCE: {source}")

    try:
        return app_server_rate_limits()
    except QuotaReadError:
        if env_flag("CODEX_QUOTA_ALLOW_SESSION_FALLBACK"):
            return latest_codex_rate_limits()
        raise


def write_json_file(path: Path, payload: dict) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = path.with_name(f"{path.name}.tmp")
        temp_path.write_text(json.dumps(payload, ensure_ascii=False, sort_keys=True), encoding="utf-8")
        temp_path.replace(path)
    except Exception as error:
        log_line("cache-error", f"Cannot write quota cache {path}: {error}")


def write_success_cache(
    five_hour: float,
    five_hour_reset: datetime | None,
    weekly: float,
    weekly_reset: datetime | None,
) -> None:
    now = datetime.now().astimezone().isoformat(timespec="seconds")
    write_json_file(
        cache_file,
        {
            "fiveHourRemainingPercent": float(five_hour),
            "fiveHourResetAt": date_to_text(five_hour_reset),
            "weeklyRemainingPercent": float(weekly),
            "weeklyResetAt": date_to_text(weekly_reset),
            "refreshedAt": now,
            "consecutiveFailures": 0,
        },
    )


def read_cache_payload() -> dict | None:
    try:
        payload = json.loads(cache_file.read_text(encoding="utf-8"))
    except Exception:
        return None
    return payload if isinstance(payload, dict) else None


def cached_rate_limits_after_error(error: QuotaReadError) -> tuple[float, datetime | None, float, datetime | None]:
    payload = read_cache_payload()
    if payload is None:
        raise error

    try:
        failures = int(payload.get("consecutiveFailures", 0)) + 1
    except Exception:
        failures = 1

    payload["consecutiveFailures"] = failures
    payload["lastErrorAt"] = datetime.now().astimezone().isoformat(timespec="seconds")
    payload["lastError"] = str(error)
    write_json_file(cache_file, payload)

    if failures >= STALE_ERROR_THRESHOLD:
        raise QuotaReadError(
            f"{error} (showing error after {failures} consecutive failed refreshes; cached quota is at {cache_file})"
        )

    five_hour = payload.get("fiveHourRemainingPercent", payload.get("five_hour_remaining_percent"))
    weekly = payload.get("weeklyRemainingPercent", payload.get("weekly_remaining_percent"))
    five_hour_reset = parse_date(payload.get("fiveHourResetAt", payload.get("five_hour_reset_at")))
    weekly_reset = parse_date(payload.get("weeklyResetAt", payload.get("weekly_reset_at")))

    if five_hour is None or weekly is None:
        raise error

    log_line("stale", f"Using cached quota after failed refresh {failures}/{STALE_ERROR_THRESHOLD}: {error}")
    return float(five_hour), five_hour_reset, float(weekly), weekly_reset


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


try:
    if display_mode == "refresh-mtmr":
        subprocess.Popen(
            [
                "/bin/sh",
                "-c",
                "sleep 0.2; /usr/bin/pkill -x MTMR || true; /usr/bin/open -a /Applications/MTMR.app",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        emit(localized("↻ 刷新中", "↻ refreshing"))
        sys.exit(0)

    try:
        five_hour, five_hour_reset, weekly, weekly_reset = current_codex_rate_limits()
        write_success_cache(five_hour, five_hour_reset, weekly, weekly_reset)
    except QuotaReadError as error:
        try:
            five_hour, five_hour_reset, weekly, weekly_reset = cached_rate_limits_after_error(error)
        except QuotaReadError:
            if not env_flag("CODEX_QUOTA_USE_FALLBACK"):
                raise
            five_hour, five_hour_reset, weekly, weekly_reset = local_quota_fallback()
            if five_hour is None or weekly is None:
                raise QuotaReadError(f"Fallback quota file is missing or invalid: {quota_file}")

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
except Exception as error:
    emit_error(str(error))
PY
