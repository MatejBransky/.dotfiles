# Worktree Switcher

Integration for LazyVim's `Snacks.lazygit` launcher. The native LazyGit
`Switch` action and its `Space` mapping remain unchanged.

`<leader>gg` still opens LazyGit through Snacks in `LazyVim.root.git()`. The
plugin passes `LAZYGIT_NEW_DIR_FILE` to that process and synchronizes Neovim's
cwd as soon as LazyGit writes the new worktree path. The terminal is also
checked once more when it closes.

## Configuration

```lua
{
  enabled = true,
}
```

The parent shell that launched Neovim cannot be changed by a child Neovim
process. For shell usage, use LazyGit's `LAZYGIT_NEW_DIR_FILE` wrapper from
its README.

The terminal title format is shared with zsh through
`~/.config/zsh/tab-title-format`, which is used by both the zsh hooks and the
Neovim integration.

## API

```lua
require("libs.worktree_switcher").switch_to("/path/to/worktree")
```
