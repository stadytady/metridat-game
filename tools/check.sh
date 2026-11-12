#!/usr/bin/env bash
# Everything before a commit, in one command: import, content lint, then
# tools/test.sh (unit tests, QA scenarios, the scripted walkthrough and the
# report in build/qa/index.html). Fails on the first red step.
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"

"$godot" --headless --path . --import >/dev/null 2>&1 || true
"$godot" --headless --path . -s res://tools/lint_content.gd
exec bash tools/test.sh
