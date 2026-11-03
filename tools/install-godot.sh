#!/usr/bin/env bash
# Installs Godot (and optionally export templates) with SHA-512 verification.
#   GODOT_VERSION=4.5.1 tools/install-godot.sh [--templates]
# Puts the binary at $GODOT_BIN_DIR/godot (default ~/.local/bin).
# Templates: only Web (no threads) and Linux x86_64 are extracted, not the full 1.3 GB set.
set -euo pipefail

ver="${GODOT_VERSION:?set GODOT_VERSION, e.g. 4.5.1}"
bin_dir="${GODOT_BIN_DIR:-$HOME/.local/bin}"
tpl_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${ver}.stable"
base="https://github.com/godotengine/godot/releases/download/${ver}-stable"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fetch() { curl -fsSL --retry 4 --retry-delay 2 -o "$work/$1" "$base/$1"; }
verify() { (cd "$work" && grep " $1\$" SHA512-SUMS.txt | sha512sum -c --quiet -); }

fetch SHA512-SUMS.txt

if ! "$bin_dir/godot" --version 2>/dev/null | grep -q "^${ver}.stable"; then
  zip="Godot_v${ver}-stable_linux.x86_64.zip"
  fetch "$zip" && verify "$zip"
  mkdir -p "$bin_dir"
  unzip -q -o "$work/$zip" -d "$work"
  install -m 0755 "$work/Godot_v${ver}-stable_linux.x86_64" "$bin_dir/godot"
fi
"$bin_dir/godot" --headless --version

if [[ "${1:-}" == "--templates" && ! -f "$tpl_dir/version.txt" ]]; then
  tpz="Godot_v${ver}-stable_export_templates.tpz"
  fetch "$tpz" && verify "$tpz"
  mkdir -p "$tpl_dir"
  unzip -q -o -j "$work/$tpz" \
    'templates/version.txt' \
    'templates/web_nothreads_*.zip' \
    'templates/linux_*.x86_64' \
    -d "$tpl_dir"
  ls -la "$tpl_dir"
fi
