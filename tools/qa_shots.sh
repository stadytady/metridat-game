#!/usr/bin/env bash
# QA scenarios with the real renderer (Forward+, lavapipe under Xvfb without a
# GPU), so the frames their shot() takes land in the report next to the steps.
#   tools/qa_shots.sh OUT_DIR [scenario ...]     (all of them by default)
#   RES=1280x800 tools/qa_shots.sh OUT_DIR       (another window: Steam Deck)
# Writes scenario_<name>.json and shots/ into OUT_DIR and rebuilds its
# index.html, so it can run over a folder tools/test.sh already filled.
set -uo pipefail
cd "$(dirname "$0")/.."
out="$(realpath -m "${1:?output dir}")"; shift || true
godot="${GODOT:-godot}"
res="${RES:-1920x1080}"
mkdir -p "$out"
names=("$@")
if [[ ${#names[@]} -eq 0 ]]; then
  mapfile -t names < <(ls tests/scenarios/*.gd | xargs -n1 basename | sed 's/\.gd$//')
fi
if [[ -z "${DISPLAY:-}" ]]; then
  icd="$(compgen -G '/usr/share/vulkan/icd.d/lvp_icd*.json' | head -n1 || true)"
  export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$icd}"
  wrap=(xvfb-run -a -s "-screen 0 ${res}x24")
else
  wrap=()
fi
status=0
for name in "${names[@]}"; do
  # 15 frames a second of game time (every figure animates at 15 anyway): a
  # quarter of the frames to draw on a software renderer; every clock in the
  # game runs on delta and physics still steps at 60, so nothing else changes
  "${wrap[@]}" "$godot" --path . --rendering-driver vulkan --resolution "$res" --fixed-fps 15 \
    -- --qa="$name" --qa-out="$out" 2>&1 | grep -E --line-buffered '^qa |FAIL|SCENARIO|SCRIPT ERROR' || true
  grep -q '"status": "ok"' "$out/scenario_$name.json" 2>/dev/null || status=1
done
python3 tools/qa_report.py "$out" || true
exit $status
