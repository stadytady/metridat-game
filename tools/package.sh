#!/usr/bin/env bash
# Packages the exports in build/ for players, the same way for CI artifacts
# and GitHub Releases:
#   dist/Panticapaeum-<ver>-windows-x86_64.zip   Panticapaeum.exe + console.exe + README.txt
#   dist/Panticapaeum-<ver>-linux-x86_64.tar.gz  tar keeps the executable bit (zip does not)
#   dist/Panticapaeum-<ver>-web.zip, -trailer.mp4, SHA256SUMS.txt
#   tools/package.sh VERSION
set -euo pipefail
cd "$(dirname "$0")/.."
ver="${1:?version, e.g. v0.0.1}"
name="Panticapaeum-${ver}"
rm -rf dist
mkdir -p dist/stage/windows dist/stage/linux

cat > dist/stage/README.txt <<TXT
Panticapaeum: Echoes of the Bosporus ${ver}

Windows: run Panticapaeum.exe. The exe is not code-signed, so SmartScreen may
say "Windows protected your PC": click "More info" -> "Run anyway".
If the game does not start, run Panticapaeum.console.exe instead: it opens a
console with the engine log, send that text with the bug report.
Needs a GPU with Vulkan (any GeForce/Radeon/Intel Arc from the last decade);
without Vulkan Godot falls back to OpenGL.

Linux: tar xzf the archive and run ./panticapaeum.x86_64

Controls: WASD, mouse, Shift run, Space jump, E inspect, Esc pause, F3 stats.
Benchmark: run with  -- --benchmark
TXT

cp build/windows/Panticapaeum.exe dist/stage/windows/
if [[ -f build/windows/Panticapaeum.console.exe ]]; then
  cp build/windows/Panticapaeum.console.exe dist/stage/windows/
fi
cp dist/stage/README.txt dist/stage/windows/
(cd dist/stage/windows && zip -9 -q -r "../../${name}-windows-x86_64.zip" .)

install -m 0755 build/linux/panticapaeum.x86_64 dist/stage/linux/
cp dist/stage/README.txt dist/stage/linux/
tar -C dist/stage -czf "dist/${name}-linux-x86_64.tar.gz" --transform "s,^linux,${name}," linux

if [[ -s build/web/index.wasm ]]; then
  (cd build/web && zip -9 -q -r "../../dist/${name}-web.zip" .)
fi
cp docs/trailer.mp4 "dist/${name}-trailer.mp4"
rm -rf dist/stage
(cd dist && sha256sum ./*.zip ./*.tar.gz ./*.mp4 > SHA256SUMS.txt)
ls -la dist
