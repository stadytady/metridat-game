#!/usr/bin/env bash
# Release exports into build/. Needs export templates for the engine version.
#   tools/export.sh [windows] [linux] [web]   (default: windows linux)
set -euo pipefail
cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
mkdir -p build/windows build/linux build/web
touch build/.gdignore
"$godot" --headless --path . --import >/dev/null 2>&1 || true
for t in "${@:-windows linux}"; do
  for p in $t; do
    case "$p" in
      windows) "$godot" --headless --path . --export-release "Windows Desktop" build/windows/Panticapaeum.exe
               test -s build/windows/Panticapaeum.exe ;;
      linux)   "$godot" --headless --path . --export-release "Linux" build/linux/panticapaeum.x86_64
               test -s build/linux/panticapaeum.x86_64 ;;
      web)     "$godot" --headless --path . --export-release "Web" build/web/index.html
               test -s build/web/index.wasm ;;
      *) echo "unknown target: $p" >&2; exit 2 ;;
    esac
  done
done
