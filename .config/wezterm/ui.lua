local module = {}

---@param config Config
function module.apply_to_config(config)
	config.font_size = 14
	config.hide_tab_bar_if_only_one_tab = true
	config.tab_bar_at_bottom = true
	config.tab_max_width = 250
	config.use_fancy_tab_bar = false
	config.initial_cols = 120
	config.initial_rows = 40
	config.window_decorations = "RESIZE"
	config.window_background_opacity = 0.9
	config.macos_window_background_blur = 30

	require("tab_bar").apply_to_config(config)
end

return module
