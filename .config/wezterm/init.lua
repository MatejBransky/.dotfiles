local wezterm = require("wezterm")
local colorscheme = require("colorscheme")

local config = wezterm.config_builder()

require("scrollback-to-nvim").register()
require("mappings").apply_to_config(config)
colorscheme.apply_to_config(config)
colorscheme.sync_theme()
require("ui").apply_to_config(config)

return config
