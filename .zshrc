source ~/.config/zsh/zshrc

cfg() {
  git --git-dir="$HOME/.cfg" --work-tree="$HOME" "$@"
}

export SSH_AUTH_SOCK=/Users/matejbransky/.bitwarden-ssh-agent.sock

# Created by `pipx` on 2026-05-15 15:08:33
export PATH="$PATH:/Users/matejbransky/.local/bin"

# pnpm
export PNPM_HOME="/Users/matejbransky/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"

# bun completions
[ -s "/Users/matejbransky/.bun/_bun" ] && source "/Users/matejbransky/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by codebase-memory-mcp install
export PATH="/Users/matejbransky/.local/bin:$PATH"
