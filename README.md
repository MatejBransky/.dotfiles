# Dotfiles

Bare Git repository for the personal workstation setup.

## Quick Start

```bash
git clone --bare git@github.com:MatejBransky/.dotfiles.git "$HOME/.cfg"
git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout main
cp "$HOME/.config/workstation/git-exclude" "$HOME/.cfg/info/exclude"
brew bundle --file="$HOME/.config/workstation/Brewfile" --no-upgrade
source "$HOME/.zshrc"
```

For daily use:

```bash
cfg status
cfgui
cfgvim
```

Full documentation is available in [`~/.config/workstation/README.md`](.config/workstation/README.md).

The repository uses the personal Git identity through `includeIf` for `~/.cfg`. Repositories in `~/Developer/work/` use the work identity; repositories in `~/Developer/personal/` and this dotfiles repository use the personal identity. SSH private keys are provided by the Bitwarden agent.

The complete work/personal Git identity layout, `includeIf` examples and Bitwarden SSH agent setup are documented in [`.config/workstation/README.md`](.config/workstation/README.md#git-identity-and-ssh).

The same document also lists the required, optional and internal environment variables in its [Environment Variables](.config/workstation/README.md#environment-variables) section.
