# layout-launcher

Pick a tab/pane layout from a list, spawn it into the current window, run its commands.

## Usage

- `Cmd+Shift+L` → fuzzy-pick a layout → tabs/panes get appended to the current window, each leaf's `command` is launched.
- `Cmd+Shift+Alt+L` → same picker, same layout, but every pane's `command` is typed into the prompt without being submitted — review/edit and press Enter yourself. No need for a second, command-less copy of the layout.

## Layout sources

- **Local**: `.wezterm-layouts/*.json` in a repo — one file per layout, found by walking up from the active pane's cwd. First `.wezterm-layouts/` dir found wins (nested repo beats an outer one).
- **Global**: `layout-launcher/layouts/*.json` (this directory) — same one-file-per-layout convention.

Filename (minus `.json`) is the fallback name in the picker if `name` is omitted.

## Schema

See [schema.json](schema.json). Summary:

```json
{
  "name": "string",
  "description": "string (optional, shown in the picker)",
  "root": "string (optional, ~ supported)",
  "tabs": [
    {
      "label": "string (optional, defaults to WezTerm's normal tab title: cwd + the active pane's running command)",
      "cwd": "string (optional, relative to root)",
      "layout": { "...pane node, optional" }
    }
  ]
}
```

Pane node — leaf:
```json
{ "cwd": "./frontend", "command": ["yarn", "dev"], "size": 1 }
```

Pane node — split (`row` = side by side, `column` = stacked; `size` = fr weight per child):
```json
{ "direction": "row", "panes": [ {"size": 2, ...}, {"size": 1, ...} ] }
```

`command` can be a string (sent as-is) or an array (shell-quoted and joined). Commands run via `send_text` into an interactive shell, so a crash doesn't kill the pane.

## Root resolution (for relative `cwd`s)

1. explicit `root` in the layout JSON
2. otherwise: cwd of the pane that opened the picker

Applies to local and global layouts alike — a local layout works from any subdirectory (or, e.g., from any git worktree if `.wezterm-layouts/` sits above several of them) as long as you invoke the picker from the directory the layout's paths should be relative to.

Keybindings (`openLayoutPicker` / `openLayoutPickerStaged`) live with every other shortcut in [../keybindings.lua](../keybindings.lua) and [../mappings.lua](../mappings.lua), not in this directory.

## Files

- `picker.lua` — discovery + `InputSelector` + root resolution
- `discover.lua` — finds local/global layout files
- `builder.lua` — spawns tabs, recursively splits panes, sends commands
- `loader.lua` — JSON read/parse
- `path.lua` — path helpers (`~` expand, join, shell quoting)
- `layouts/example.json` — sample layout
