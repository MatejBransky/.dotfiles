# Workstation Dotfiles

Single bare Git repository for the workstation configuration.

The repository uses:

- `~/.cfg` as the Git directory
- `$HOME` as the Git work tree
- `Brewfile` as the list of direct Homebrew dependencies
- `node-globals` as the list of global npm/pnpm CLI packages
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
- `~/.finicky.ts`
- `~/Applications/Brave Work Opener.applescript`

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

## Browsers

Work and personal browsing are two separate Brave builds, not two profiles inside one app:

- **Work** — stable Brave (`com.brave.Browser`, cask `brave-browser`), profile `Profile 1`.
- **Personal** — Brave Beta (`com.brave.Browser.beta`, cask `brave-browser@beta`), single profile.

Two applications instead of one, because activating a browser raises all of its windows in every Space; with both profiles in stable Brave, focusing work dragged the personal window over the terminal on the other display.

Finicky (`~/.finicky.ts`, cask `finicky`) is the default browser and the registered handler for `public.html`. It decides where each URL goes:

| URL opened from | Browser |
| --- | --- |
| work apps (Slack, Outlook, Teams, Cursor, Claude, Figma, ClickUp PWA) | work |
| Slack channels listed in `PERSONAL_SLACK_CHANNELS` | personal |
| terminal, CLI, local `file://` URLs (no opener) | work |
| everything else | personal |

Work URLs go through `~/Applications/Brave Work Opener.app`, a small AppleScript applet that raises an existing normal Brave window before handing the URL over — Chromium opens a new window when the last active Brave window is an app-mode/PWA window. The applet source is tracked in this repository as `Applications/Brave Work Opener.applescript` (the compiled `.app` is not); the rebuild command is in its header.

`~/.local/src/brave-focus.swift` toggles focus between the two builds; see its header for the commands.

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

## Global Node Packages

`node-globals` lists the global CLI packages installed with npm and pnpm. Each line has the form `<npm|pnpm> <package>`:

```text
pnpm varlock
npm vercel
```

`bootstrap.sh` installs every entry after `brew bundle`. To apply the list to an existing machine:

```bash
while read -r manager package _; do
  case "$manager" in '' | '#'*) continue ;; esac
  case "$manager" in
    npm) npm install --global "$package" ;;
    pnpm) pnpm add --global "$package" ;;
  esac
done <"$HOME/.config/workstation/node-globals"
```

The pnpm global prefix is version-specific (`~/Library/pnpm/global/v11`), so it is recreated by the current pnpm major instead of being tracked. Versions are not pinned; add a package name with `@version` when a specific release matters.

npm and corepack ship with Node, which `fnm` manages, and therefore are not listed.

## Updates and Maintenance

After changes from another machine:

```bash
cfg pull --ff-only
cfg checkout
brew bundle install --file="$HOME/.config/workstation/Brewfile" --no-upgrade
```

Global npm/pnpm packages are restored by `bootstrap.sh`; re-run the loop from [Global Node Packages](#global-node-packages) after editing `node-globals`.

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

The global `~/.gitconfig` uses `includeIf` to keep work and personal identities separate. Git selects an included config based on the path of the repository's Git directory:

```ini
[includeIf "gitdir:~/Developer/work/"]
    path = ~/Developer/work/.gitconfig
[includeIf "gitdir:~/Developer/personal/"]
    path = ~/Developer/personal/.gitconfig
[includeIf "gitdir:~/.cfg"]
    path = ~/Developer/personal/.gitconfig
```

The expected layout is:

```text
~/.gitconfig
~/Developer/work/.gitconfig
~/Developer/personal/.gitconfig
~/.cfg
~/.ssh/id_pub_work
~/.ssh/id_pub_personal
```

The global config contains shared Git behavior and routing rules:

```ini
[gpg]
    format = ssh
[core]
    editor = nvim

[includeIf "gitdir:~/Developer/work/"]
    path = ~/Developer/work/.gitconfig
[includeIf "gitdir:~/Developer/personal/"]
    path = ~/Developer/personal/.gitconfig
[includeIf "gitdir:~/.cfg"]
    path = ~/Developer/personal/.gitconfig
```

The work and personal files contain identity-specific settings:

```ini
# ~/Developer/work/.gitconfig
[user]
    name = Matej Bransky
    email = work@example.com
    signingkey = ssh-ed25519 WORK_PUBLIC_KEY
[core]
    sshCommand = "ssh -i ~/.ssh/id_pub_work"
```

```ini
# ~/Developer/personal/.gitconfig
[user]
    name = Matej Bransky
    email = personal@example.com
    signingkey = ssh-ed25519 PERSONAL_PUBLIC_KEY
[core]
    sshCommand = "ssh -i ~/.ssh/id_pub_personal"
```

The dotfiles repository is personal, so `~/.cfg` loads `~/Developer/personal/.gitconfig` and uses the personal name, email, SSH signing key and SSH command. The `gitdir:~/.cfg` rule intentionally has no trailing slash because `~/.cfg` is the bare Git directory itself.

## Bitwarden SSH Agent

SSH private keys are stored in Bitwarden and are never committed or kept as ordinary files in `~/.ssh/`. The Bitwarden SSH agent provides the private key when OpenSSH uses the matching public-key identity:

```text
~/.ssh/id_pub_work      # public key only
~/.ssh/id_pub_personal  # public key only
```

The SSH agent must be running and unlocked before Git operations that use SSH. The SSH socket is exposed through `SSH_AUTH_SOCK`; its exact path is machine-specific and is configured locally in the shell environment rather than stored as a secret in this repository.

The `core.sshCommand` setting selects the correct public-key identity for each repository scope. Bitwarden then supplies the corresponding private key through its agent.

## Directory Profiles

Direnv is installed through `Brewfile` and loaded at the end of `~/.config/zsh/zshrc`. The machine-local profile files are intentionally outside Git:

```text
~/.envrc                         # default work profile
~/Developer/personal/.envrc      # personal override
```

The work profile is sourced before the direnv hook and reapplied when direnv unloads the last `.envrc`, so directories outside any `.envrc` ancestry (for example `/tmp`) still use work. Entering `~/Developer/personal` loads the personal override; leaving it restores work.

Both profiles obtain the GitHub token from the existing `gh` keyring login and export it as both `GH_TOKEN` and `GITHUB_TOKEN`. No token is stored in `.envrc`. Review and authorize each local file after creating it:

```bash
direnv allow ~/.envrc
direnv allow ~/Developer/personal/.envrc
```

The personal profile also selects `~/.claude-personal`. Work leaves `CLAUDE_CONFIG_DIR` unset so Claude uses its normal `~/.claude` and `~/.claude.json` layout. Cursor currently remains work-only: `CURSOR_CONFIG_DIR` separates settings but not browser authentication, so a future personal Cursor account needs its own `CURSOR_API_KEY`.

Git keeps identity, signing and SSH routing in the existing `includeIf` files. A broad work fallback appears before the specific personal rules, so scratch repositories default to work without duplicating `GIT_AUTHOR_*` variables in direnv.

OpenCode is personal-only. New worktrees are created under each canonical checkout's `.git/opencode-worktrees`, and the `workstation.direnv` V2 plugin loads the nearest profile for shell commands and MCP servers. For older linked worktrees outside the personal tree, the plugin resolves the canonical worktree before falling back to the home-level work profile.

Direnv affects interactive shells and processes that explicitly use `direnv exec`. GUI applications and daemons need their own launch environment; the OpenCode plugin covers OpenCode's shell and MCP processes specifically.

## Environment Variables

Most variables are set by the shell configuration, direnv, or macOS.

| Variable | Required | Purpose | Source |
|---|---:|---|---|
| `HOME` | Yes | User home directory used by all dotfiles paths | macOS |
| `PATH` | Yes | Finds Homebrew and the installed tools | macOS, Homebrew and shell setup |
| `SSH_AUTH_SOCK` | For SSH | Points Git/OpenSSH to the Bitwarden SSH agent socket | Local machine setup |
| `GH_TOKEN`, `GITHUB_TOKEN` | For GitHub API access | Selected personal/work GitHub token | Local `.envrc`, read from `gh` keyring |
| `WORKSTATION_PROFILE` | Recommended | Explicit `work` or `personal` profile marker | Local `.envrc` |
| `CLAUDE_CONFIG_DIR` | Personal Claude only | Uses `~/.claude-personal`; unset for work | Local `.envrc` |
| `CURSOR_CONFIG_DIR` | Recommended | Cursor settings directory; not an authentication boundary | Local `.envrc` |
| `DEV_DB_HOST`, `DEV_DB_PORT`, `DEV_DB_USER`, `DEV_DB_NAME` | Work DB helpers | Local PostgreSQL connection settings | Work `.envrc` |
| `MOMENCE_USER_EMAIL`, `MOMENCE_USER_PASSWORD` | Work integrations only | Momence test credentials; removed in personal mode | Work shell environment, never Git |
| `EDITOR` | Recommended | Default editor; set to `nvim` | `~/.config/zsh/dev.zsh` |
| `XDG_CONFIG_HOME` | Recommended | Configuration root; set to `$HOME/.config` | `~/.config/zsh/path.zsh` |
| `PYENV_ROOT` | If using pyenv | pyenv installation path; defaults to `$HOME/.pyenv` | `~/.config/zsh/path.zsh` |
| `PNPM_HOME` | If using pnpm | pnpm executable directory; set to `$HOME/Library/pnpm` | `~/.config/zsh/dev.zsh` |
| `FZF_DEFAULT_COMMAND` | No | Default file listing command for fzf | `~/.config/zsh/dev.zsh` |
| `FZF_CTRL_T_COMMAND` | No | File listing command used by fzf `Ctrl-T` | `~/.config/zsh/dev.zsh` |
| `HOMEBREW_NO_ENV_HINTS` | No | Disables Homebrew environment hints | `~/.config/zsh/dev.zsh` |
| `OPENAI_API_BASE` | No | API endpoint used by company-specific shell helpers | `~/.config/zsh/company.zsh` |
| `OPENAI_API_KEY` | Only for API helpers | API credential for integrations that require it | Local secret manager, never Git |

`GIT_DIR`, `GIT_WORK_TREE`, `NVIM_CWD_FILE` and `LAZYGIT_NEW_DIR_FILE` are short-lived internal variables used by `cfgvim` and the Neovim/LazyGit integration. They do not need to be configured manually.

`SSH_AUTH_SOCK` must point to a running, unlocked Bitwarden SSH agent before using SSH remotes. The socket path is machine-specific and must not be replaced with a private key in this repository.

`OPENAI_API_KEY` is intentionally not stored in the repository. Set it only in the local shell, a password manager integration or another machine-local secret mechanism when a helper actually needs it.

Verify the effective configuration without printing token values:

```bash
direnv status
printf '%s\n' "$WORKSTATION_PROFILE"
gh api user --jq .login
git config --show-origin --get user.email
git config --show-origin --get core.sshCommand
git config --show-origin --get commit.gpgsign
printf '%s\n' "${CLAUDE_CONFIG_DIR-unset}" "$CURSOR_CONFIG_DIR"
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
