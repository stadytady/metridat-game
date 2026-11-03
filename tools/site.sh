#!/usr/bin/env bash
# Assembles the GitHub Pages site in build/site from the landing page,
# the trailer and the web export (build/web, see tools/export.sh web).
set -euo pipefail
cd "$(dirname "$0")/.."
test -s build/web/index.wasm || { echo "run tools/export.sh web first" >&2; exit 1; }
rm -rf build/site
mkdir -p build/site/play
cp web/index.html build/site/
cp docs/trailer.mp4 build/site/trailer.mp4
# Poster: the title frame of the trailer (falls back to a screenshot).
ffmpeg -v error -y -ss 23.5 -i docs/trailer.mp4 -frames:v 1 build/site/poster.png \
  || cp docs/hill.png build/site/poster.png
cp build/web/index.icon.png build/site/icon.png
cp -r build/web/. build/site/play/
# GitHub Pages runs Jekyll unless told not to; it would skip nothing here but is slower.
touch build/site/.nojekyll
du -sh build/site
