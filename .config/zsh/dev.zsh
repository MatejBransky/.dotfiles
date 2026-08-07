# homebrew
export HOMEBREW_NO_ENV_HINTS=true
register_command 'eval "$(/opt/homebrew/bin/brew shellenv)"' $PRIORITY_3

# syntax highlighting
register_command 'source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' $PRIORITY_3

export EDITOR=nvim

alias nv='NVIM_APPNAME=nvim-custom nvim'
alias lvim='NVIM_APPNAME=nvim-lazyvim nvim'
alias avim='NVIM_APPNAME=nvim-astronvim nvim'
alias nvtest='nvim --headless -u NONE -l scripts/minitest.lua'

# Keep the parent shell in sync when Neovim changes its cwd (for example via
# LazyGit worktree switching). Neovim writes the final cwd on VimLeavePre.
function nvim() {
  local cwd_file="${TMPDIR:-/tmp}/nvim-cwd-$$"
  NVIM_CWD_FILE="$cwd_file" command nvim "$@"
  if [[ -f "$cwd_file" ]]; then
    local new_cwd
    new_cwd="$(command cat "$cwd_file")"
    if [[ -n "$new_cwd" && -d "$new_cwd" ]]; then
      builtin cd -- "$new_cwd"
    fi
    command rm -f "$cwd_file"
  fi
}

function gwcd() {
  path=$(git worktree list | grep "$1" | awk '{print $1}')
  if [ -n "$path" ]; then
    cd "$path"
  else
    echo "Worktree '$1' not found"
  fi
}

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

# git
alias gc='git commit'
alias lg='lazygit'
alias cfgui='lazygit --git-dir="$HOME/.cfg" --work-tree="$HOME"'

function cfgvim() (
  builtin cd -- "$HOME" || return
  GIT_DIR="$HOME/.cfg" GIT_WORK_TREE="$HOME" nvim "$@"
)

# node (fnm)
register_command 'eval "$(fnm env --use-on-cd --shell zsh)"' $PRIORITY_3

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
alias pm="pnpm"
alias pi="pnpm install"

# Nx
alias move="pnpm nx g mv"

alias js="jsonschema metaschema -h"

alias gcp="opencode run --model github-copilot/claude-sonnet-4 do !gcp"

# fzf - command-line fuzzy finder
# respect .gitignore
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
# to apply the command to CTRL-T as well
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
# set up fzf key bindings and fuzzy completion
register_command 'source <(fzf --zsh)' $PRIORITY_3

# . "$HOME/.atuin/bin/env"
# register_command 'eval "$(atuin init zsh)"' $PRIORITY_2

# zoxide - smarter cd command
# for completions to work, the below line must be added after `compinit` is called.
# You may have to rebuild your completions cache by running `rm ~/.zcompdump*; compinit`.
register_command 'eval "$(zoxide init zsh)"' $PRIORITY_3
