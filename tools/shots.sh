#!/usr/bin/env bash
# Renders viewpoint screenshots with the real Forward+ renderer.
# Without a GPU: software Vulkan (Mesa lavapipe) under Xvfb.
#   tools/shots.sh OUT_DIR [--only=hill,agora]
#   RES=1280x800 tools/shots.sh OUT_DIR --only=ui   # another window: Steam Deck, 21:9
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(realpath -m "${1:?output dir}")"; shift || true
godot="${GODOT:-godot}"
res="${RES:-1920x1080}"
args=(--path . --rendering-driver vulkan --resolution "$res")
run=("$godot" "${args[@]}" -- --shots "--out=$out" "$@")
if [[ -z "${DISPLAY:-}" ]]; then
  # Debian names it lvp_icd.json, Ubuntu lvp_icd.x86_64.json.
  icd="$(compgen -G '/usr/share/vulkan/icd.d/lvp_icd*.json' | head -n1 || true)"
  export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$icd}"
  xvfb-run -a -s "-screen 0 ${res}x24" "${run[@]}"
else
  "${run[@]}"
fi
