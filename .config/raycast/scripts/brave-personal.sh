#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Brave Personal
# @raycast.mode silent
# @raycast.packageName Browsers
# @raycast.icon 🏠
# @raycast.description Focus the Personal Brave window (toggle, opens one if missing)
# @raycast.keywords personal brave

sock="$HOME/Library/Caches/brave-focus/sock"

if [ -S "$sock" ] && [ "$(printf 'personal\n' | /usr/bin/nc -U -w 2 "$sock" 2>/dev/null)" = "ok" ]; then
  exit 0
fi

"$HOME/.local/bin/brave-focus" personal
