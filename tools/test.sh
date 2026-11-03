#!/usr/bin/env bash
# Import, unit tests, scripted walkthrough of the whole slice (real physics).
# Fails on test failures and on any SCRIPT ERROR (GDScript does not abort on them).
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

"$godot" --headless --path . --import >/dev/null 2>&1 || true
"$godot" --headless --path . -s res://tests/run_tests.gd 2>&1 | tee -a "$log"
"$godot" --headless --path . --fixed-fps 60 -- --walkthrough 2>&1 | tee -a "$log"
grep -q "WALKTHROUGH PASS" "$log"
if grep -qE 'SCRIPT ERROR|Parse Error' "$log"; then
  echo "script errors in Godot output" >&2
  exit 1
fi
