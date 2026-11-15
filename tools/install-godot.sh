#!/usr/bin/env bash
# Installs Godot (and optionally export templates) with SHA-512 verification.
#   GODOT_VERSION=4.5.1 tools/install-godot.sh [--templates]
# Puts the binary at $GODOT_BIN_DIR/godot (default ~/.local/bin).
# Templates: only Windows x86_64, Linux x86_64 and Web (no threads) are extracted
# from the 1.3 GB archive.
# Nothing is downloaded for what is already there: CI restores the binary and
# the templates from actions/cache, and then this script must not touch GitHub
# Releases at all (its 502/503s failed runs before the tests started). Only a
# cache miss downloads, with retries spread over minutes, not seconds.
set -euo pipefail

ver="${GODOT_VERSION:?set GODOT_VERSION, e.g. 4.5.1}"
bin_dir="${GODOT_BIN_DIR:-$HOME/.local/bin}"
tpl_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${ver}.stable"
base="https://github.com/godotengine/godot/releases/download/${ver}-stable"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# curl retries timeouts, 408, 429 and 5xx (not a 404: a wrong version fails at once)
fetch() {
  curl -fsSL --connect-timeout 20 --retry 8 --retry-delay 15 --retry-max-time 300 \
    -o "$work/$1" "$base/$1"
}
# the checksums are fetched once, and only when there is something to verify
verify() {
  [[ -f "$work/SHA512-SUMS.txt" ]] || fetch SHA512-SUMS.txt
  (cd "$work" && grep " $1\$" SHA512-SUMS.txt | sha512sum -c --quiet -)
}

if ! "$bin_dir/godot" --version 2>/dev/null | grep -q "^${ver}.stable"; then
  zip="Godot_v${ver}-stable_linux.x86_64.zip"
  # two commands, not `fetch && verify`: set -e ignores a failure left of &&,
  # and a broken download would be unpacked unverified
  fetch "$zip"
  verify "$zip"
  mkdir -p "$bin_dir"
  unzip -q -o "$work/$zip" -d "$work"
  install -m 0755 "$work/Godot_v${ver}-stable_linux.x86_64" "$bin_dir/godot"
fi
"$bin_dir/godot" --headless --version

if [[ "${1:-}" == "--templates" && ! -f "$tpl_dir/web_nothreads_release.zip" ]]; then
  tpz="Godot_v${ver}-stable_export_templates.tpz"
  fetch "$tpz"
  verify "$tpz"
  mkdir -p "$tpl_dir"
  unzip -q -o -j "$work/$tpz" \
    'templates/version.txt' \
    'templates/windows_*_x86_64*.exe' \
    'templates/linux_*.x86_64' \
    'templates/web_nothreads_*.zip' \
    -d "$tpl_dir"
  ls -la "$tpl_dir"
fi
