# Dotfiles

Bare Git repository pro osobní workstation setup.

## Rychlý start

```bash
git clone --bare git@github.com:MatejBransky/.dotfiles.git "$HOME/.cfg"
git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout main
cp "$HOME/.config/workstation/git-exclude" "$HOME/.cfg/info/exclude"
brew bundle --file="$HOME/.config/workstation/Brewfile" --no-upgrade
source "$HOME/.zshrc"
```

Pro běžnou práci:

```bash
cfg status
cfgui
cfgvim
```

Kompletní dokumentace je v [`~/.config/workstation/README.md`](.config/workstation/README.md).

Repozitář používá osobní Git identitu přes `includeIf` pro `~/.cfg`. Pracovní repozitáře v `~/Developer/work/` používají pracovní identitu; osobní repozitáře v `~/Developer/personal/` a dotfiles používají osobní identitu. SSH privátní klíče poskytuje Bitwarden agent.
