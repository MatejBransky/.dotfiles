local wezterm = require("wezterm")

local module = {}

---@param config Config
function module.apply_to_config(config)
	---@type Palette
	local active_scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]

	-- Helper function to safely apply color modifications
	local function modify_color(color, lighten_amount, darken_amount)
		local parsed_color = wezterm.color.parse(color)
		if lighten_amount then
			return tostring(parsed_color:lighten(lighten_amount))
		elseif darken_amount then
			return tostring(parsed_color:darken(darken_amount))
		else
			return color
		end
	end

	-- Configure tab bar colors based on active color scheme
	config.colors = {
		tab_bar = {
			background = modify_color(active_scheme.background, nil, 0.1),
			active_tab = {
				bg_color = modify_color(active_scheme.background, 0.1, nil),
				fg_color = modify_color(active_scheme.foreground, nil, nil),
			},
			inactive_tab = {
				bg_color = modify_color(active_scheme.background, nil, 0.05),
				fg_color = modify_color(active_scheme.foreground, nil, 0.3),
			},
			new_tab = {
				bg_color = modify_color(active_scheme.background, nil, 0.05),
				fg_color = modify_color(active_scheme.foreground, nil, 0.3),
			},
			inactive_tab_hover = {
				bg_color = modify_color(active_scheme.background, nil, 0.02),
				fg_color = modify_color(active_scheme.foreground, 0.1, nil),
			},
			new_tab_hover = {
				bg_color = modify_color(active_scheme.background, nil, 0.02),
				fg_color = modify_color(active_scheme.foreground, 0.1, nil),
			},
		},
	}
end

return module
