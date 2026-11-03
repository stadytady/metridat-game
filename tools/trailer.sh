#!/usr/bin/env bash
# Renders the 25 s trailer with Godot's Movie Maker (frame-exact, any GPU),
# then encodes H.264 + AAC with ffmpeg.
#   tools/trailer.sh [OUT.mp4]      default: docs/trailer.mp4
#   SIZE=1920x1080 tools/trailer.sh out.mp4   (default 1280x720: an exact 2x of the
#   640x360 internal image, crisp and a third of the size of 1080p)
# Without a GPU it runs on Mesa lavapipe under Xvfb (a few minutes).
set -euo pipefail
cd "$(dirname "$0")/.."
out="$(realpath -m "${1:-docs/trailer.mp4}")"
godot="${GODOT:-godot}"
size="${SIZE:-1280x720}"
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT

"$godot" --headless --path . --import >/dev/null 2>&1 || true
run=("$godot" --path . --rendering-driver vulkan --resolution 1920x1080
  --write-movie "$frames/trailer.png" --fixed-fps 30 --quit-after 760 -- --trailer)
if [[ -z "${DISPLAY:-}" ]]; then
  icd="$(compgen -G '/usr/share/vulkan/icd.d/lvp_icd*.json' | head -n1 || true)"
  export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-$icd}"
  xvfb-run -a -s "-screen 0 1920x1080x24" "${run[@]}"
else
  "${run[@]}"
fi

# Pixel art: keep chroma at full resolution would need yuv444p, which many
# players reject; yuv420p at a low CRF is the compatible compromise.
ffmpeg -y -loglevel error -framerate 30 -i "$frames/trailer%08d.png" -i "$frames/trailer.wav" \
  -vf "scale=${size/x/:}:flags=neighbor" \
  -c:v libx264 -preset slow -crf "${CRF:-20}" -pix_fmt yuv420p -movflags +faststart \
  -af "loudnorm=I=-16:TP=-1.5:LRA=11" -c:a aac -b:a 192k -ar 48000 -shortest "$out"
echo "trailer: $out"
