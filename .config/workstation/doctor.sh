#!/bin/sh
set -eu

BREWFILE="$HOME/.config/workstation/Brewfile"
failed=0

check_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'ok   %-18s %s\n' "$1" "$(command -v "$1")"
  else
    printf 'miss %-18s\n' "$1"
    failed=1
  fi
}

if command -v brew >/dev/null 2>&1; then
  brew bundle check --file="$BREWFILE" --no-upgrade >/dev/null 2>&1 \
    && printf '%s\n' 'ok   Brewfile dependencies' \
    || { printf '%s\n' 'miss Brewfile dependencies'; failed=1; }
else
  printf '%s\n' 'miss Homebrew'
  failed=1
fi

for command_name in zsh nvim lazygit yazi rg fd fzf jq zoxide opencode node pnpm python3; do
  check_command "$command_name"
done

if [ -d "$HOME/.cfg" ]; then
  git --git-dir="$HOME/.cfg" --work-tree="$HOME" status --short
else
  printf '%s\n' 'miss ~/.cfg bare repository'
  failed=1
fi

exit "$failed"
