# wezterm config

Personal [WezTerm](https://wezterm.org) config for macOS. Entry point is `~/.wezterm.lua` (outside this repo, symlinked/pointed at `init.lua` here — see Setup).

## Structure

- `init.lua` — wires everything below into one `config_builder()` config.
- `keybindings.lua` — every keybinding's key/mods, in one place, by name.
- `mappings.lua` — turns `keybindings.lua` entries into actual `config.keys` actions.
- `ui.lua` — font size, tab bar placement, window decorations/opacity/blur.
- `tab_bar.lua` — tab bar colors derived from the active color scheme.
- `scrollback-to-nvim.lua` — dumps the current pane's scrollback to a temp file and opens it in nvim.
- `colorscheme/` — color scheme presets with light/dark auto-switching (see below).
- `layout-launcher/` — custom plugin to pick a tab/pane layout from a list and spawn it (see below).

## Features

### Color scheme presets (`colorscheme/`)

`presets.json` maps named presets to a light/dark WezTerm scheme (and, for future use, a matching Neovim colorscheme name). `Ctrl+Shift+T` cycles the mode: `auto` (follows macOS appearance) → `light` → `dark` → back to `auto`. State lives in `colorscheme/preset.config.json` (chosen preset + mode) and `colorscheme/theme` (last-resolved light/dark, used to detect OS appearance changes on reload) — both are gitignored local runtime state and self-heal to sane defaults if missing (see `ensure_config()`).

### Scrollback to nvim (`Cmd+e`)

Opens the last 2000 lines of the current pane's scrollback in nvim, in a new tab. Requires `nvim` on `PATH`.

### Layout launcher (`layout-launcher/`)

Picks a tab/pane layout from a list and spawns it into the *current* window. A layout is a JSON file describing tabs, a recursive row/column pane split tree with CSS-`fr`-style size weights, and an optional shell command per pane. See [layout-launcher/README.md](layout-launcher/README.md) for the full schema and design notes.

- `Cmd+Shift+L` — pick a layout, commands run automatically.
- `Cmd+Shift+Alt+L` — same picker, but commands are typed into the prompt and not submitted (review/edit before running).

Layouts come from two places:
- **Global**, reusable from anywhere: `layout-launcher/layouts/*.json`.
- **Local**, per-project: a `.wezterm-layouts/*.json` directory anywhere above the pane's cwd (e.g. useful at the root of a git-worktree-based monorepo, so one layout definition works from any worktree).

## Keybindings

All `Cmd`/`Ctrl`/`Alt` below is WezTerm's `SUPER`/`CTRL`/`ALT` — on macOS that's ⌘/⌃/⌥.

| Keys | Action |
| --- | --- |
| `Ctrl+Shift+T` | Cycle color scheme mode (auto/light/dark) |
| `Cmd+P` | Quick-select a URL in the pane and open it |
| `Ctrl+Shift+E` | Rename the current tab |
| `Cmd+R` | Swap panes (pick target, keep focus) |
| `Cmd+Ctrl+w` | Close current pane (confirm) |
| `Cmd+e` | Scrollback → nvim |
| `Cmd+Shift+L` | Open layout picker (runs commands) |
| `Cmd+Shift+Alt+L` | Open layout picker (stages commands, no auto-run) |
| `Cmd+h/j/k/l` | Focus pane left/down/up/right |
| `Cmd+Ctrl+h/j/k/l` | Split pane left/down/up/right |
| `Cmd+Alt+h/j/k/l` | Resize pane left/down/up/right (5 cells) |

## Setup on a new machine

1. `git clone` this repo to `~/.config/wezterm`.
2. Point WezTerm's entry point at it — either `wezterm.lua` in this directory, or `~/.wezterm.lua` containing `return require("init")` (WezTerm auto-adds its config directory to the Lua `package.path`, so a bare `require("init")` resolves to `init.lua` here). This repo does not include that entry file since it lives outside `~/.config/wezterm/`.
3. Install [Nerd Fonts](https://www.nerdfonts.com) if tab bar / icons look wrong (not currently pinned to a specific font in this config).
4. `nvim` must be on `PATH` for `Cmd+e` (scrollback-to-nvim) to work.
5. First launch will self-heal `colorscheme/preset.config.json` and `colorscheme/theme` with defaults (`preset = "default"`, `mode = "auto"`).

## Known limitations

- `colorscheme/preset_switcher.lua` is an inert stub (empty `apply_to_config`, nothing requires it) — dead code kept around from an earlier iteration; safe to delete.
- No runtime validation of layout JSON against `layout-launcher/schema.json` — a malformed layout file can produce a Lua error instead of a clean message. `schema.json` is currently editor/documentation-only.
- `layout-launcher` commands run via `pane:send_text` into a live shell — that's the intentional design (you pick a layout, its commands run), not a sandboxed execution model.
