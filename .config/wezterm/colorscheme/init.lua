---@type Wezterm
local wezterm = require("wezterm")

local colorscheme_dir = require("colorscheme.constants").colorscheme_dir

local constants = {
	PRESETS_PATH = colorscheme_dir .. "/presets.json",
	CONFIG_PATH = colorscheme_dir .. "/preset.config.json",
	THEME_PATH = colorscheme_dir .. "/theme",
}

local module = {}

-- ---------- helpers ----------

---Read presets from JSON file
local function read_presets()
	local file = io.open(constants.PRESETS_PATH, "r")
	if not file then
		return nil
	end
	local content = file:read("*a")
	file:close()

	if not content or content == "" then
		return nil
	end

	local ok, data = pcall(wezterm.json_parse, content)
	if not ok then
		return nil
	end

	return data.presets
end

---Resolve color scheme from preset and theme
---@param preset string
---@param theme string
---@return string|nil scheme
local function resolve_scheme(preset, theme)
	local presets = read_presets()

	if not presets then
		return nil
	end

	local current_preset = presets[preset]
	if not current_preset then
		return nil
	end

	return current_preset.wezterm[theme]
end

---Get current OS theme
---@return "dark"|"light" theme
local function os_theme()
	local appearance = wezterm.gui.get_appearance()
	return appearance:find("Dark") and "dark" or "light"
end

---Read configuration from JSON file
local function read_config()
	local file = io.open(constants.CONFIG_PATH, "r")
	if not file then
		return nil
	end
	local content = file:read("*a")
	file:close()

	if not content or content == "" then
		return nil
	end
	local ok, data = pcall(wezterm.json_parse, content)
	if not ok then
		return nil
	end
	return data
end

---Write configuration to JSON file
local function write_config(cfg)
	local file = assert(io.open(constants.CONFIG_PATH, "w"))
	file:write(wezterm.json_encode(cfg))
	file:close()
end

---Read current theme from file
---@return string|nil theme
local function read_theme()
	local file = io.open(constants.THEME_PATH, "r")
	if not file then
		return nil
	end
	local theme = file:read("*l")
	file:close()
	return theme
end

---Write theme to file
local function write_theme(theme)
	local file = assert(io.open(constants.THEME_PATH, "w"))
	file:write(theme)
	file:close()
end

-- ---------- public API ----------

---Toggle between auto, light, and dark modes
function module.toggle_mode()
	local cfg = module.ensure_config()
	if cfg.mode == "auto" then
		cfg.mode = "light"
	elseif cfg.mode == "light" then
		cfg.mode = "dark"
	else
		cfg.mode = "auto"
	end
	write_config(cfg)
	wezterm.reload_configuration()
end

---Ensure configuration exists, create default if needed
function module.ensure_config()
	local cfg = read_config()
	if cfg then
		return cfg
	end

	cfg = {
		preset = "default",
		mode = "auto", -- auto | light | dark
	}
	write_config(cfg)

	return cfg
end

---Sync theme file with current configuration
function module.sync_theme()
	local cfg = module.ensure_config()
	local resolved = cfg.mode == "light" and "light" or cfg.mode == "dark" and "dark" or os_theme()
	local current = read_theme()

	if current ~= resolved then
		write_theme(resolved)
	end
end

---Apply color scheme to Wezterm config
function module.apply_to_config(config)
	local cfg = module.ensure_config()
	local theme = cfg.mode == "auto" and os_theme() or cfg.mode

	local scheme = resolve_scheme(cfg.preset, theme)

	wezterm.log_info("Colorscheme preset '" .. cfg.preset .. "' for theme '" .. theme .. "'")
	wezterm.log_info("Theme mode: " .. cfg.mode)
	wezterm.log_info("Colorscheme: " .. (scheme or "nil"))

	if scheme then
		config.color_scheme = scheme
	end
end

---Add config file to watch list for auto-reload
function module.watch()
	wezterm.add_to_config_reload_watch_list(constants.CONFIG_PATH)
end

return module
