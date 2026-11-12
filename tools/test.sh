#!/usr/bin/env bash
# Import, unit tests, QA scenarios (tests/scenarios, one process each, from a
# fixture), the scripted walkthrough of the whole slice (real physics), then the
# HTML report: build/qa/index.html (QA_OUT moves it; SCENARIOS="a b" runs only
# those). Fails on test failures and on any SCRIPT ERROR (GDScript does not
# abort on them); the report is written either way.
set -uo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
out="${QA_OUT:-build/qa}"
rm -rf "$out"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
log="$out/console.log"
status=0

"$godot" --headless --path . --import >/dev/null 2>&1 || true
"$godot" --headless --path . -s res://tests/run_tests.gd -- --json="$out/unit.json" 2>&1 | tee -a "$log" || status=1
for name in ${SCENARIOS:-$(ls tests/scenarios/*.gd | xargs -n1 basename | sed 's/\.gd$//')}; do
  "$godot" --headless --path . --fixed-fps 60 -- --qa="$name" --qa-out="$out" 2>&1 | tee -a "$log" || status=1
done
"$godot" --headless --path . --fixed-fps 60 -- --walkthrough --qa-out="$out" 2>&1 | tee -a "$log" || status=1
grep -q "WALKTHROUGH PASS" "$log" || status=1
if grep -qE 'SCRIPT ERROR|Parse Error' "$log"; then
  echo "script errors in Godot output" >&2
  status=1
fi
python3 tools/qa_report.py "$out" || true
exit $status
