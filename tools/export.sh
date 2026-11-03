#!/usr/bin/env bash
# Exports release builds into build/. Needs templates: tools/install-godot.sh --templates
#   tools/export.sh [Web|Linux]...   (default: both)
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
mkdir -p build/web build/linux
# Keep Godot from importing exported files as project resources.
touch build/.gdignore
"$godot" --headless --import >/dev/null 2>&1 || true
for preset in "${@:-Web Linux}"; do
  for p in $preset; do
    case "$p" in
      Web) out=build/web/index.html ;;
      Linux) out=build/linux/metridat.x86_64 ;;
      *) echo "unknown preset: $p" >&2; exit 2 ;;
    esac
    "$godot" --headless --export-release "$p" "$out"
    test -s "$out"
  done
done
