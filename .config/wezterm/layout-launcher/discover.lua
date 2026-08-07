local wezterm = require("wezterm")
local path = require("layout-launcher.path")
local loader = require("layout-launcher.loader")

local GLOBAL_DIR = wezterm.home_dir .. "/.config/wezterm/layout-launcher/layouts"
local LOCAL_DIRNAME = ".wezterm-layouts"

local module = {}
module.GLOBAL_DIR = GLOBAL_DIR

---Walk up from `start_dir` looking for a `.wezterm-layouts/` directory that
---contains at least one layout. Stops at the first one found, so a nested
---repo's own layouts take precedence over an outer one.
---@param start_dir string
---@return string[] files
local function find_local_layouts(start_dir)
	local dir = start_dir
	while dir and dir ~= "" do
		local files = wezterm.glob(dir .. "/" .. LOCAL_DIRNAME .. "/*.json")
		if #files > 0 then
			return files
		end

		local parent = path.dirname(dir)
		if parent == dir then
			break
		end
		dir = parent
	end
	return {}
end

---Discover every layout available from the given trigger pane: every
---per-repo layout under `.wezterm-layouts/` (found by walking up from the
---pane's cwd) plus every global layout under `layout-launcher/layouts/`.
---@param pane Pane
---@return table[] entries { id, name, description, source }
function module.find_all(pane)
	local entries = {}

	local cwd_url = pane:get_current_working_dir()
	local cwd = cwd_url and cwd_url.file_path

	if cwd then
		for _, file in ipairs(find_local_layouts(cwd)) do
			local layout = loader.read(file)
			if layout then
				table.insert(entries, {
					id = file,
					name = layout.name or file:match("([^/]+)%.json$"),
					description = layout.description,
					source = { kind = "local", path = file },
				})
			end
		end
	end

	for _, file in ipairs(wezterm.glob(GLOBAL_DIR .. "/*.json")) do
		local layout = loader.read(file)
		if layout then
			table.insert(entries, {
				id = file,
				name = layout.name or file:match("([^/]+)%.json$"),
				description = layout.description,
				source = { kind = "global", path = file },
			})
		end
	end

	return entries
end

return module
