#!/bin/sh
set -eu

REPO_URL=${1:?Usage: bootstrap.sh <git-repository-url>}
CFG_DIR="$HOME/.cfg"
BREWFILE="$HOME/.config/workstation/Brewfile"

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

printf '%s\n' "Workstation setup installed. Start a new shell and run: cfg status"
