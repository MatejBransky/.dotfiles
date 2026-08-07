# Functions to synchronize the terminal tab title with the current working directory (cwd).
# These functions are useful in any terminal that supports dynamic title updates (e.g. WezTerm).
# They allow the terminal tab title to reflect the current directory and the command being executed,
# making it easy to track your location and active command in the terminal.

# Function to set the tab title during command execution.
# This function is triggered right before a command is executed in the terminal.
# It updates the terminal tab title to display the current working directory (`%~`)
# followed by the command that is being executed (`$1`).
#
# \e]0; - Starts the escape sequence for setting the terminal's title.
# %~    - Zsh escape sequence for the current working directory.
# •$1   - Adds the bullet (•) and the name of the command being executed ($1).
# \a    - Ends the escape sequence, signaling the terminal to update the title.
function preexec() {
  local title
  title="$($HOME/.config/zsh/tab-title-format "$PWD" "$1")"
  print -Pn "\e]0;${title}\a"
}

# Function to reset the tab title after command completion.
# This function is triggered after a command finishes executing. 
# It resets the terminal tab title to display only the current working directory (`%~`),
# cleaning up the title from the previous command.
#
# \e]0; - Starts the escape sequence for setting the terminal's title.
# %~    - Zsh escape sequence for the current working directory.
# \a    - Ends the escape sequence, updating the title to reflect the current directory only.
function precmd() {
    local title
    title="$($HOME/.config/zsh/tab-title-format "$PWD")"
    print -Pn "\e]0;${title}\a"
}
