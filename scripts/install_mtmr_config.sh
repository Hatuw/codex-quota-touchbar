#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_CONFIG="$ROOT_DIR/mtmr/items.template.json"
SCRIPT_PATH="$ROOT_DIR/scripts/codex_quota_touchbar.sh"
MTMR_DIR="$HOME/Library/Application Support/MTMR"
TARGET_CONFIG="$MTMR_DIR/items.json"

if [[ ! -f "$TEMPLATE_CONFIG" ]]; then
  echo "Cannot find MTMR template: $TEMPLATE_CONFIG" >&2
  exit 1
fi

if [[ ! -x "$SCRIPT_PATH" ]]; then
  chmod +x "$SCRIPT_PATH"
fi

COMMAND="$(/usr/bin/python3 - "$SCRIPT_PATH" <<'PY'
import shlex
import sys

print(f"{shlex.quote(sys.argv[1])} compact-bar")
PY
)"

mkdir -p "$MTMR_DIR"

if [[ -f "$TARGET_CONFIG" ]]; then
  backup="$TARGET_CONFIG.backup.$(/bin/date +%Y%m%d%H%M%S)"
  cp "$TARGET_CONFIG" "$backup"
  echo "Backed up existing MTMR config: $backup"
fi

/usr/bin/python3 - "$TEMPLATE_CONFIG" "$TARGET_CONFIG" "$COMMAND" "$SCRIPT_PATH" <<'PY'
from pathlib import Path
import json
import sys

template_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
command = sys.argv[3]
script_path = sys.argv[4]

data = json.loads(template_path.read_text(encoding="utf-8"))


def replace_placeholders(value):
    if isinstance(value, dict):
        return {key: replace_placeholders(item) for key, item in value.items()}
    if isinstance(value, list):
        return [replace_placeholders(item) for item in value]
    if value == "__CODEX_QUOTA_COMMAND__":
        return command
    if value == "__CODEX_QUOTA_SCRIPT_PATH__":
        return script_path
    return value


target_path.write_text(
    json.dumps(replace_placeholders(data), ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

echo "Installed MTMR config: $TARGET_CONFIG"
echo "Restart MTMR to apply the Touch Bar changes:"
echo "  pkill -x MTMR || true"
echo "  open -a /Applications/MTMR.app"
