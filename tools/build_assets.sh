#!/usr/bin/env bash
# Regenerates every generated asset: textures, materials, sounds (Python),
# then the GLB models (Godot). Output is committed; run after changing generators.
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
python3 tools/gen_assets.py
"$godot" --headless --path . --import >/dev/null 2>&1 || true
"$godot" --headless --path . -s res://tools/bake_models.gd
"$godot" --headless --path . --import >/dev/null 2>&1 || true
