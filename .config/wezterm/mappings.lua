local wezterm = require("wezterm")
local keybindings = require("keybindings")

local module = {}

---@param config Config
function module.apply_to_config(config)
	config.keys = {
		{
			key = "T",
			mods = "CTRL|SHIFT",
			action = wezterm.action_callback(function()
				require("colorscheme").toggle_mode()
			end),
		},
		{
			key = keybindings.quickSelect.key,
			mods = keybindings.quickSelect.mods,
			action = wezterm.action.QuickSelectArgs({
				patterns = {
					"https?://\\S+",
				},
				action = wezterm.action_callback(function(window, pane)
					local url = window:get_selection_text_for_pane(pane)
					wezterm.log_info("opening: " .. url)
					wezterm.open_with(url)
				end),
			}),
		},

		{
			key = keybindings.nameTab.key,
			mods = keybindings.nameTab.mods,
			action = wezterm.action.PromptInputLine({
				description = "Enter new name for tab",
				---@diagnostic disable-next-line: unused-local
				action = wezterm.action_callback(function(window, pane, line)
					-- line will be `nil` if they hit escape without entering anything
					-- An empty string if they just hit enter
					-- Or the actual line of text they wrote
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},

		{
			key = keybindings.swapPane.key,
			mods = keybindings.swapPane.mods,
			action = wezterm.action.PaneSelect({
				mode = "SwapWithActiveKeepFocus",
			}),
		},

		{
			key = keybindings.closePane.key,
			mods = keybindings.closePane.mods,
			action = wezterm.action.CloseCurrentPane({ confirm = true }),
		},

		{
			key = keybindings.scrollbackToNvim.key,
			mods = keybindings.scrollbackToNvim.mods,
			action = wezterm.action({ EmitEvent = "trigger-vim-with-scrollback" }),
		},

		{
			key = keybindings.openLayoutPicker.key,
			mods = keybindings.openLayoutPicker.mods,
			action = wezterm.action_callback(function(window, pane)
				require("layout-launcher.picker").show(window, pane)
			end),
		},
		{
			key = keybindings.openLayoutPickerStaged.key,
			mods = keybindings.openLayoutPickerStaged.mods,
			action = wezterm.action_callback(function(window, pane)
				require("layout-launcher.picker").show(window, pane, { stage_commands = true })
			end),
		},

		{
			key = keybindings.focusPaneUp.key,
			mods = keybindings.focusPaneUp.mods,
			action = wezterm.action.ActivatePaneDirection("Up"),
		},
		{
			key = keybindings.focusPaneDown.key,
			mods = keybindings.focusPaneDown.mods,
			action = wezterm.action.ActivatePaneDirection("Down"),
		},
		{
			key = keybindings.focusPaneLeft.key,
			mods = keybindings.focusPaneLeft.mods,
			action = wezterm.action.ActivatePaneDirection("Left"),
		},
		{
			key = keybindings.focusPaneRight.key,
			mods = keybindings.focusPaneRight.mods,
			action = wezterm.action.ActivatePaneDirection("Right"),
		},

		{
			key = keybindings.splitPaneUp.key,
			mods = keybindings.splitPaneUp.mods,
			action = wezterm.action.SplitPane({ direction = "Up" }),
		},
		{
			key = keybindings.splitPaneDown.key,
			mods = keybindings.splitPaneDown.mods,
			action = wezterm.action.SplitPane({ direction = "Down" }),
		},
		{
			key = keybindings.splitPaneLeft.key,
			mods = keybindings.splitPaneLeft.mods,
			action = wezterm.action.SplitPane({ direction = "Left" }),
		},
		{
			key = keybindings.splitPaneRight.key,
			mods = keybindings.splitPaneRight.mods,
			action = wezterm.action.SplitPane({ direction = "Right" }),
		},

		{
			key = keybindings.resizePaneUp.key,
			mods = keybindings.resizePaneUp.mods,
			action = wezterm.action.AdjustPaneSize({ "Up", 5 }),
		},
		{
			key = keybindings.resizePaneDown.key,
			mods = keybindings.resizePaneDown.mods,
			action = wezterm.action.AdjustPaneSize({ "Down", 5 }),
		},
		{
			key = keybindings.resizePaneLeft.key,
			mods = keybindings.resizePaneLeft.mods,
			action = wezterm.action.AdjustPaneSize({ "Left", 5 }),
		},
		{
			key = keybindings.resizePaneRight.key,
			mods = keybindings.resizePaneRight.mods,
			action = wezterm.action.AdjustPaneSize({ "Right", 5 }),
		},
	}
end

return module
