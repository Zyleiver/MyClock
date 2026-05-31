#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build

STATUS_OUTPUT="$(scripts/codex-clock-status running "Smoke testing MyClock")"
python3 - "$STATUS_OUTPUT" <<'PY'
import json
import os
import sys

payload = json.loads(sys.argv[1])
assert payload["status"] == "running"
assert payload["task"] == "Smoke testing MyClock"

status_path = os.path.expanduser("~/.codex-clock/status.json")
with open(status_path, "r", encoding="utf-8") as file:
    saved = json.load(file)

assert saved == payload
print("Status bridge OK")
PY

scripts/build-app.sh >/dev/null
test -x build/MyClock.app/Contents/MacOS/MyClock
echo "Build app OK"
