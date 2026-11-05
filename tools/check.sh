#!/usr/bin/env bash
# Everything before a commit, in one command: import, content lint, unit tests and
# the scripted walkthrough. Fails on the first red step.
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"

"$godot" --headless --path . --import >/dev/null 2>&1 || true
"$godot" --headless --path . -s res://tools/lint_content.gd
"$godot" --headless --path . -s res://tests/run_tests.gd

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$godot" --headless --path . --fixed-fps 60 -- --walkthrough 2>&1 | tee -a "$log"
grep -q "WALKTHROUGH PASS" "$log"
if grep -qE 'SCRIPT ERROR|Parse Error' "$log"; then
  echo "script errors in Godot output" >&2
  exit 1
fi
