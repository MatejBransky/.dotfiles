local path = require("layout-launcher.path")

local module = {}

---@param direction "row"|"column"|nil
---@return "Right"|"Bottom"
local function split_direction(direction)
	return direction == "column" and "Bottom" or "Right"
end

---Build the literal command line to send into a freshly spawned pane.
---@param command string|string[]|nil
---@return string|nil
local function command_line(command)
	if not command then
		return nil
	end
	if type(command) == "string" then
		return command
	end

	local parts = {}
	for _, arg in ipairs(command) do
		table.insert(parts, path.shell_quote(arg))
	end
	return table.concat(parts, " ")
end

---Apply a single pane node (leaf or split) onto an already-created pane.
---@param pane Pane
---@param node table
---@param parent_cwd string
---@param stage_commands boolean if true, the leaf command is typed into the prompt but not submitted
local function apply_node(pane, node, parent_cwd, stage_commands)
	local cwd = path.join(parent_cwd, node.cwd)

	if node.panes then
		local n = #node.panes
		local weights = {}
		for i, child in ipairs(node.panes) do
			weights[i] = child.size or 1
		end

		-- suffix_sum[i] = sum of weights[i..n]; used to convert each child's
		-- "fr" weight into the Percent size WezTerm's binary split expects.
		local suffix_sum = {}
		suffix_sum[n + 1] = 0
		for i = n, 1, -1 do
			suffix_sum[i] = suffix_sum[i + 1] + weights[i]
		end

		local direction = split_direction(node.direction)
		local cursor = pane

		for i = 1, n - 1 do
			local fraction = suffix_sum[i + 1] / suffix_sum[i]
			local new_pane = cursor:split({ direction = direction, size = fraction, cwd = cwd })
			apply_node(cursor, node.panes[i], cwd, stage_commands)
			cursor = new_pane
		end

		apply_node(cursor, node.panes[n], cwd, stage_commands)
		return
	end

	-- Leaf pane: always cd explicitly (harmless if already there) then,
	-- if given, launch the long-lived command into the interactive shell
	-- rather than replacing it, so a crash doesn't take the pane down too.
	-- `clear` afterwards wipes the cd (and the clear itself) from scrollback,
	-- so the pane's history starts clean at whatever runs next.
	pane:send_text("cd " .. path.shell_quote(cwd) .. "\r")
	pane:send_text("clear\r")

	local line = command_line(node.command)
	if line then
		if stage_commands then
			-- Type it into the prompt without submitting, so it can be
			-- reviewed (or edited) before running it manually.
			pane:send_text(line)
		else
			pane:send_text(line .. "\r")
		end
	end
end

---Spawn every tab described by `layout` into `window`, appending them to
---whatever tabs it already has.
---@param window Window window that triggered the picker
---@param layout table parsed layout JSON
---@param root string resolved base directory for the layout
---@param opts table|nil { stage_commands: boolean } — every pane still gets cd'd; stage_commands only changes whether the leaf `command` is submitted or just typed in
function module.apply(window, layout, root, opts)
	opts = opts or {}
	local mux_window = window:mux_window()

	for _, tab_spec in ipairs(layout.tabs) do
		local tab_cwd = path.join(root, tab_spec.cwd)
		local tab, pane = mux_window:spawn_tab({ cwd = tab_cwd })

		if tab_spec.label then
			tab:set_title(tab_spec.label)
		end

		if tab_spec.layout then
			apply_node(pane, tab_spec.layout, tab_cwd, opts.stage_commands)
		end
	end
end

return module
