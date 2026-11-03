#!/usr/bin/env bash
# Imports the project, runs unit tests and a smoke run of the main scene.
# Fails on test failures and on any SCRIPT ERROR (GDScript does not abort on them).
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

"$godot" --headless --import >/dev/null 2>&1 || true

run() {
  local rc=0
  "$godot" --headless "$@" 2>&1 | tee -a "$log" || rc=$?
  return "$rc"
}

run -s res://tests/run_tests.gd
# Main scene for ~2 s of frames: catches errors in UI scripts that unit tests do not load.
run --quit-after 120 res://scenes/main.tscn

if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' "$log"; then
  echo "errors in Godot output, see above" >&2
  exit 1
fi
