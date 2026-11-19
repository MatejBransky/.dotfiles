#!/bin/sh
set -eu

REPO_URL=${1:?Usage: bootstrap.sh <git-repository-url>}
CFG_DIR="$HOME/.cfg"
BREWFILE="$HOME/.config/workstation/Brewfile"
NODE_GLOBALS="$HOME/.config/workstation/node-globals"

install_node_globals() {
  [ -f "$1" ] || return 0
  while read -r manager package _; do
    case "$manager" in
      '' | '#'*) continue ;;
    esac
    case "$manager" in
      npm) npm install --global "$package" ;;
      pnpm) pnpm add --global "$package" ;;
      *) printf 'Unknown package manager in %s: %s\n' "$1" "$manager" >&2 ;;
    esac
  done <"$1"
}

if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [ ! -d "$CFG_DIR" ]; then
  git clone --bare "$REPO_URL" "$CFG_DIR"
fi

cfg() {
  git --git-dir="$CFG_DIR" --work-tree="$HOME" "$@"
}

cfg config --local status.showUntrackedFiles no
cfg checkout
if [ -f "$HOME/.config/workstation/git-exclude" ]; then
  cp "$HOME/.config/workstation/git-exclude" "$CFG_DIR/info/exclude"
fi
brew bundle --file="$BREWFILE" --no-upgrade
install_node_globals "$NODE_GLOBALS"

printf '%s\n' "Workstation setup installed. Start a new shell and run: cfg status"
