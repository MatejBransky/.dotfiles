local wezterm = require("wezterm")
local discover = require("layout-launcher.discover")
local loader = require("layout-launcher.loader")
local builder = require("layout-launcher.builder")
local path = require("layout-launcher.path")

local module = {}

---Resolve the base directory a layout's relative paths are relative to.
---Order: explicit `root` in the JSON > cwd of the pane that triggered the
---picker. This applies to local and global layouts alike, so a shared
---local layout (e.g. one sitting above several git worktrees) resolves
---against whichever worktree you were in when you opened the picker.
---@param layout table
---@param trigger_pane Pane
---@return string|nil
local function resolve_root(layout, trigger_pane)
	if layout.root then
		return path.expand_home(layout.root)
	end

	local cwd_url = trigger_pane:get_current_working_dir()
	return cwd_url and cwd_url.file_path
end

---@param window Window
---@param pane Pane
---@param opts table|nil { stage_commands: boolean }
function module.show(window, pane, opts)
	opts = opts or {}
	local entries = discover.find_all(pane)

	if #entries == 0 then
		wezterm.log_info("layout-launcher: no layouts found (local or global)")
		return
	end

	local choices = {}
	for _, entry in ipairs(entries) do
		local label = entry.name
		if entry.source.kind == "local" then
			label = label .. " (local)"
		end
		if entry.description then
			label = label .. "  \xe2\x80\x94  " .. entry.description
		end
		table.insert(choices, { id = entry.id, label = label })
	end

	local mode = opts.stage_commands and "commands staged, not auto-run" or "commands auto-run"
	local heading = "Select a layout (" .. mode .. ")"

	window:perform_action(
		wezterm.action.InputSelector({
			title = heading,
			description = heading .. "  —  Enter = accept, Esc = cancel, / = filter",
			fuzzy = true,
			fuzzy_description = heading .. "  —  Fuzzy matching: ",
			choices = choices,
			action = wezterm.action_callback(function(inner_window, inner_pane, id)
				if not id then
					return
				end

				local entry
				for _, candidate in ipairs(entries) do
					if candidate.id == id then
						entry = candidate
						break
					end
				end
				if not entry then
					wezterm.log_error("layout-launcher: could not find entry for " .. id)
					return
				end

				local layout = loader.read(entry.id)
				if not layout then
					wezterm.log_error("layout-launcher: could not read " .. entry.id)
					return
				end

				local root = resolve_root(layout, inner_pane)
				if not root then
					wezterm.log_error("layout-launcher: could not resolve root directory for " .. entry.id)
					return
				end

				builder.apply(inner_window, layout, root, opts)
			end),
		}),
		pane
	)
end

return module
