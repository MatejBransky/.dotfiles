# Workstation Dotfiles

Jednotný bare Git repozitář pro konfiguraci pracovního prostředí.

Repozitář používá:

- `~/.cfg` jako Git directory
- `$HOME` jako Git work tree
- `Brewfile` jako seznam přímých Homebrew závislostí
- `git-exclude` jako explicitní allowlist sledovaných souborů

## Co repozitář obsahuje

- `~/.zshrc` a `~/.zprofile`
- `~/.gitconfig`
- `~/.config/zsh/`
- `~/.config/nvim/`
- `~/.config/wezterm/`
- `~/.config/lazygit/`
- `~/.config/yazi/`
- `~/.config/opencode/`
- `~/.config/workstation/`

Lokální data, secrets, `.claude` overrides, Node dependencies, screenshoty a vendored Neovim `externals/` se nesledují.

## Nový stroj

Nejprve musí být dostupný Git a přístup k repozitáři. Na macOS je Git obvykle součástí Command Line Tools.

```bash
git clone --bare git@github.com:USER/workstation.git "$HOME/.cfg"
git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout main
```

Po checkoutu se nastaví allowlist a nainstalují Homebrew balíky:

```bash
cp "$HOME/.config/workstation/git-exclude" "$HOME/.cfg/info/exclude"
brew bundle --file="$HOME/.config/workstation/Brewfile" --no-upgrade
source "$HOME/.zshrc"
```

Jakmile je repozitář jednou checkoutnutý, lze stejné kroky opakovat bootstrap skriptem:

```bash
sh "$HOME/.config/workstation/bootstrap.sh" \
  git@github.com:USER/workstation.git
```

Skript nainstaluje Homebrew, naklonuje bare repo, provede checkout a spustí `brew bundle`. Na úplně čistém stroji je potřeba skript nejprve získat mimo tento checkout, nebo použít ruční sekvenci výše.

## Běžné použití

Shell funkce `cfg` pracuje s bare repem bez ohledu na aktuální adresář:

```bash
cfg status
cfg log --oneline
cfg diff
cfg add .config/zsh/dev.zsh
cfg commit -m "feat: update shell configuration"
cfg push
```

Dotfiles LazyGit:

```bash
cfgui
```

Dotfiles Neovim:

```bash
cfgvim
```

`cfgvim` otevře Neovim s `$HOME` jako worktree a nastaví `GIT_DIR` na `~/.cfg`. V Neovimu otevře `<leader>gD` LazyGit pro dotfiles. Klávesa `<leader>gg` zůstává určena pro aktuální projekt/root repo.

## Přidání nové konfigurace

1. Přidej cestu do `.config/workstation/git-exclude`.
2. Přidej stejnou cestu také do `~/.cfg/info/exclude`, aby ochrana platila okamžitě.
3. Přidej soubor přes `cfg add`.
4. Zkontroluj diff a commitni změnu.

Příklad:

```gitignore
!.config/tmux/
!.config/tmux/**
```

```bash
cfg add .config/tmux/tmux.conf
cfg diff --cached
cfg commit -m "feat: add tmux configuration"
```

Allowlist začíná pravidlem `*`, takže nový soubor nejde omylem commitnout bez explicitního povolení. `cfg add -f` toto pravidlo obchází a používej ho jen vědomě.

## Homebrew

`Brewfile` obsahuje přímé nástroje, na kterých konfigurace závisí. Aktualizaci seznamu prováděj ručně:

```bash
brew bundle add ripgrep --file="$HOME/.config/workstation/Brewfile"
brew bundle check --file="$HOME/.config/workstation/Brewfile" --no-upgrade
brew bundle install --file="$HOME/.config/workstation/Brewfile" --no-upgrade
```

Homebrew je rolling-release a `Brewfile` není přesný version lockfile. Přidání nástroje do manifestu tedy deklaruje jeho přítomnost, ne konkrétní historickou verzi.

## Aktualizace a údržba

Po změně na jiném stroji:

```bash
cfg pull --ff-only
cfg checkout
brew bundle install --file="$HOME/.config/workstation/Brewfile" --no-upgrade
```

Lokální kontrola:

```bash
sh "$HOME/.config/workstation/doctor.sh"
```

Kontrola, co je sledované:

```bash
cfg status
cfg ls-files
```

Neovim pluginy mají vlastní lockfile `~/.config/nvim/lazy-lock.json`, který je součástí repozitáře. Aktualizace pluginů proto commituj spolu s konfigurací, která je používá.

## Git identity a SSH

Globální `~/.gitconfig` používá `includeIf`, takže pracovní a osobní repozitáře mají oddělenou identitu:

```ini
[includeIf "gitdir:~/Developer/work/"]
    path = ~/Developer/work/.gitconfig
[includeIf "gitdir:~/Developer/personal/"]
    path = ~/Developer/personal/.gitconfig
[includeIf "gitdir:~/.cfg"]
    path = ~/Developer/personal/.gitconfig
```

Bare dotfiles repo je osobní repozitář, proto `~/.cfg` používá osobní jméno, e-mail, SSH signing key a osobní `core.sshCommand`. Privátní SSH klíč není v souborech; poskytuje ho Bitwarden SSH agent. Veřejný `~/.ssh/id_pub_personal` slouží pouze jako identifikátor pro SSH konfiguraci.

Ověření efektivního nastavení:

```bash
cfg config --get user.name
cfg config --get user.email
cfg config --get core.sshCommand
```

## Bezpečnost

Do repozitáře nepatří:

- SSH privátní klíče
- API keys, access tokens a passwords
- `.env` soubory
- Bitwarden nebo jiné credential databáze
- lokální permission overrides

Před prvním pushnutím zkontroluj:

```bash
cfg diff --cached
cfg ls-files
```

Repozitář zatím nemá nastavený remote. Po vytvoření vzdáleného repozitáře:

```bash
cfg remote add origin git@github.com:USER/workstation.git
cfg push -u origin main
```
