#!/usr/bin/env bash
# Installs Debian packages without trusting the Ubuntu mirror to answer:
#   tools/apt-cached.sh wine wine64 xvfb ffmpeg
# apt works out of APT_CACHE (default ~/.cache/apt): its own package lists and
# the .debs it downloaded. CI keeps that directory with actions/cache, so a warm
# run installs with no network at all (--no-download). A cold or stale cache
# falls back to the mirror, each try with a deadline (the mirror sometimes
# stalls for many minutes), and leaves the cache filled for the next run.
set -euo pipefail
cache="${APT_CACHE:-$HOME/.cache/apt}"
mkdir -p "$cache/archives/partial" "$cache/lists/partial"
sudo=""
[ "$(id -u)" -eq 0 ] || sudo="sudo"
opts=(-o "Dir::Cache::archives=$cache/archives" -o "Dir::State::lists=$cache/lists"
	-o APT::Keep-Downloaded-Packages=true -o Acquire::Retries=3)
# actions/cache runs as the runner user: root-owned lock files would stop it
own() { $sudo chown -R "$(id -u):$(id -g)" "$cache"; }

if compgen -G "$cache/lists/*_Packages*" >/dev/null &&
	$sudo apt-get install -y -qq --no-install-recommends --no-download "${opts[@]}" "$@"; then
	echo "apt-cached: $* from the cache"
	own
	exit 0
fi
for i in 1 2 3; do
	if timeout 180 $sudo apt-get update -qq "${opts[@]}" &&
		timeout 600 $sudo apt-get install -y -qq --no-install-recommends "${opts[@]}" "$@"; then
		echo "apt-cached: $* from the mirror (attempt $i)"
		# a cache carried over from last month drops the .debs the mirror no longer has
		$sudo apt-get autoclean -qq "${opts[@]}" || true
		own
		exit 0
	fi
	echo "apt-cached: attempt $i stalled or failed, retrying"
	sleep 15
done
own
exit 1
