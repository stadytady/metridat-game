#!/usr/bin/env bash
# Unpacks the player packages from dist/ (tools/package.sh) and runs the
# scripted walkthrough in each, exactly as a player would get them.
# Windows runs under Wine (headless: logic, resources, scripts; not the GPU).
set -euo pipefail
cd "$(dirname "$0")/.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

run() {  # label, command...
  local label="$1"; shift
  local out
  out="$("$@" --headless --fixed-fps 60 -- --walkthrough 2>&1 || true)"
  if grep -q "WALKTHROUGH PASS" <<<"$out"; then
    echo "smoke $label: PASS"
  else
    echo "smoke $label: FAIL"; echo "$out" | tail -30; fail=1
  fi
}

tgz="$(compgen -G 'dist/*-linux-x86_64.tar.gz' | head -n1)"
mkdir -p "$work/linux" && tar -xzf "$tgz" -C "$work/linux"
bin="$(find "$work/linux" -name panticapaeum.x86_64)"
test -x "$bin" || { echo "linux binary lost its executable bit" >&2; exit 1; }
run linux "$bin"

zip="$(compgen -G 'dist/*-windows-x86_64.zip' | head -n1)"
mkdir -p "$work/windows" && unzip -q "$zip" -d "$work/windows"
if command -v wine >/dev/null; then
  export WINEDEBUG=-all WINEPREFIX="$work/wineprefix"
  (cd "$work/windows" && run windows xvfb-run -a wine Panticapaeum.console.exe)
else
  echo "smoke windows: SKIPPED (no wine)"
fi
exit "$fail"
