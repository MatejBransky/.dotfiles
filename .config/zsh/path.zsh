# XDG_CONFIG_HOME is an environment variable that defines the location for user-specific
# configuration files. If not set, its default value is usually ~/.config.
# This allows applications to store their configuration files in a designated
# directory, helping to keep the home directory organized.
# You can change its value to specify a different directory for your configuration files.
export XDG_CONFIG_HOME="$HOME/.config"

# python (pyenv)
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# aqua
# export PATH="${AQUA_ROOT_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/aquaproj-aqua}/bin:$PATH"

