local wezterm = require("wezterm")

local module = {}

---Expand a leading "~" to the user's home directory.
---@param p string
---@return string
function module.expand_home(p)
	if p:sub(1, 1) == "~" then
		return wezterm.home_dir .. p:sub(2)
	end
	return p
end

---Join a base directory with a possibly-relative path.
---Absolute paths (and "~"-paths) are returned expanded, ignoring `base`.
---@param base string
---@param p string|nil
---@return string
function module.join(base, p)
	-- pane:get_current_working_dir() commonly reports a trailing "/" (OSC7
	-- convention); strip it so joins don't produce a doubled "//".
	base = base:gsub("/+$", "")

	if not p then
		return base
	end
	local expanded = module.expand_home(p)
	if expanded:sub(1, 1) == "/" then
		return expanded
	end

	-- Strip a redundant leading "./" (or a bare ".") so joined paths read
	-- as ".../backend" instead of "..././backend".
	if expanded == "." then
		return base
	end
	expanded = expanded:gsub("^%./", "")

	return base .. "/" .. expanded
end

---@param p string
---@return string
function module.dirname(p)
	return p:match("^(.*)/[^/]*$") or "."
end

---Single-quote a value for safe use in a POSIX shell command line.
---@param value string
---@return string
function module.shell_quote(value)
	return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

return module
