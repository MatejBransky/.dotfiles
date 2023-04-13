# show full path in zsh
#PS1='%n@%m %1/ %# '
PS1='%~ %# '

autoload bashcompinit && bashcompinit

# node version manager
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
  [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completionexport PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"

# pnpm
export PNPM_HOME="/Users/Matej.Bransky/Library/pnpm"
export PATH="$PNPM_HOME:$PATH"
# pnpm end

eval "$(zoxide init zsh)"

# fuzzy finder
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Created by `pipx` on 2023-03-24 18:21:46
export PATH="$PATH:/Users/Matej.Bransky/.local/bin"

alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
