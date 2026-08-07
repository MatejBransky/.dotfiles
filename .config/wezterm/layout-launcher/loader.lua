local wezterm = require("wezterm")

local module = {}

---Read and parse a layout JSON file.
---@param path string
---@return table|nil
function module.read(path)
	local file = io.open(path, "r")
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
		wezterm.log_error("layout-launcher: failed to parse " .. path .. ": " .. tostring(data))
		return nil
	end

	return data
end

return module
