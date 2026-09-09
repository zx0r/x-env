#!/usr/bin/env bash
# Tmux Status Bar Script: SSD Usage Monitor for macOS Apple Silicon
set -euo pipefail

# На Apple Silicon: Data-том содержит пользовательские файлы
if [[ "$(uname -m)" == "arm64" ]]; then
	VOL="/System/Volumes/Data"
else
	VOL="/"
fi

pct=$(df -P "$VOL" 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5);print $5}') || pct=0
[[ $pct -ge 90 ]] && c=red || { [[ $pct -ge 70 ]] && c=yellow || c=green; }
printf "#[fg=%s]󰋊 %s%%#[default]" "$c" "$pct"
