# Vim mode

bindkey -v

function zvm_after_init() {
  execute_commands_by 'zsh-vi-mode'
}

export ZVM_VI_SURROUND_BINDKEY="s-prefix"

source $(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# Yank to system clipboard
function zvm_vi_yank() {
  zvm_yank
  echo -n "$CUTBUFFER" | pbcopy
  zvm_exit_visual_mode
}
