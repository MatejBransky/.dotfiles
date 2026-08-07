# Workstation Dotfiles

Single bare Git repository for the workstation configuration.

The repository uses:

- `~/.cfg` as the Git directory
- `$HOME` as the Git work tree
- `Brewfile` as the list of direct Homebrew dependencies
- `git-exclude` as an explicit allowlist of tracked files

## Contents

- `~/.zshrc` and `~/.zprofile`
- `~/.gitconfig`
- `~/.config/zsh/`
- `~/.config/nvim/`
- `~/.config/wezterm/`
- `~/.config/lazygit/`
- `~/.config/yazi/`
- `~/.config/opencode/`
- `~/.config/workstation/`

Local data, secrets, `.claude` overrides, Node dependencies, screenshots and vendored Neovim `externals/` are not tracked.

## New Machine

Git access and repository access are required. On macOS, Git is usually provided by the Command Line Tools.

```bash
git clone --bare git@github.com:MatejBransky/.dotfiles.git "$HOME/.cfg"
git --git-dir="$HOME/.cfg" --work-tree="$HOME" checkout main
```

Apply the allowlist and install Homebrew packages:

```bash
cp "$HOME/.config/workstation/git-exclude" "$HOME/.cfg/info/exclude"
brew bundle --file="$HOME/.config/workstation/Brewfile" --no-upgrade
source "$HOME/.zshrc"
```

Once the repository has been checked out, the same steps can be repeated with the bootstrap script:

```bash
sh "$HOME/.config/workstation/bootstrap.sh" \
  git@github.com:MatejBransky/.dotfiles.git
```

The script installs Homebrew, clones the bare repository when needed, checks out the files and runs `brew bundle`. On a completely empty machine, obtain the script separately or use the manual sequence above first.

## Daily Use

The `cfg` shell function operates on the bare repository from any directory:

```bash
cfg status
cfg log --oneline
cfg diff
cfg add .config/zsh/dev.zsh
cfg commit -m "feat: update shell configuration"
cfg push
```

Open the dotfiles repository in LazyGit:

```bash
cfgui
```

Open the dotfiles work tree in Neovim:

```bash
cfgvim
```

`cfgvim` opens Neovim with `$HOME` as the work tree and sets `GIT_DIR` to `~/.cfg`. Inside Neovim, `<leader>gD` opens LazyGit for the dotfiles repository. `<leader>gg` remains assigned to the current project/root repository.

## Adding Configuration

1. Add the path to `.config/workstation/git-exclude`.
2. Add the same path to `~/.cfg/info/exclude` so the protection applies immediately.
3. Add the file with `cfg add`.
4. Review the diff and commit the change.

Example:

```gitignore
!.config/tmux/
!.config/tmux/**
```

```bash
cfg add .config/tmux/tmux.conf
cfg diff --cached
cfg commit -m "feat: add tmux configuration"
```

The allowlist starts with `*`, so a new file cannot be committed accidentally without being explicitly enabled. `cfg add -f` bypasses this protection and should only be used deliberately.

## Homebrew

`Brewfile` contains the direct tools required by the configuration. Maintain the list manually:

```bash
brew bundle add ripgrep --file="$HOME/.config/workstation/Brewfile"
brew bundle check --file="$HOME/.config/workstation/Brewfile" --no-upgrade
brew bundle install --file="$HOME/.config/workstation/Brewfile" --no-upgrade
```

Homebrew is rolling release and `Brewfile` is not an exact version lockfile. Adding a tool declares its presence, not a specific historical version.

## Updates and Maintenance

After changes from another machine:

```bash
cfg pull --ff-only
cfg checkout
brew bundle install --file="$HOME/.config/workstation/Brewfile" --no-upgrade
```

Run the local health check:

```bash
sh "$HOME/.config/workstation/doctor.sh"
```

Inspect tracked files:

```bash
cfg status
cfg ls-files
```

Neovim plugins have their own lockfile at `~/.config/nvim/lazy-lock.json`, which is part of this repository. Commit plugin updates together with the configuration that uses them.

## Git Identity and SSH

The global `~/.gitconfig` uses `includeIf` to keep work and personal identities separate:

```ini
[includeIf "gitdir:~/Developer/work/"]
    path = ~/Developer/work/.gitconfig
[includeIf "gitdir:~/Developer/personal/"]
    path = ~/Developer/personal/.gitconfig
[includeIf "gitdir:~/.cfg"]
    path = ~/Developer/personal/.gitconfig
```

The dotfiles repository is personal, so `~/.cfg` uses the personal name, email, SSH signing key and personal `core.sshCommand`. The private SSH key is not stored in files; it is provided by the Bitwarden SSH agent. The public `~/.ssh/id_pub_personal` file only identifies the key used by SSH.

Verify the effective configuration:

```bash
cfg config --get user.name
cfg config --get user.email
cfg config --get core.sshCommand
```

## Security

Never commit:

- SSH private keys
- API keys, access tokens or passwords
- `.env` files
- Bitwarden or other credential databases
- Local permission overrides

Before the first push, review:

```bash
cfg diff --cached
cfg ls-files
```

The remote is configured as `git@github.com:MatejBransky/.dotfiles.git`. The old pre-migration `main` is preserved as `backup/pre-bare-repo-2026-08-07`.
