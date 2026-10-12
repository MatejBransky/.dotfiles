local features = require("config.snacks.features")
local keybindings = require("keybindings").snacks

if not features.picker_cycle_preview then
  return {}
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    opts.picker.actions = opts.picker.actions or {}
    opts.picker.win = opts.picker.win or {}
    opts.picker.win.input = opts.picker.win.input or {}
    opts.picker.win.list = opts.picker.win.list or {}
    opts.picker.actions.cycle_preview = function(picker)
      local layout_config = vim.deepcopy(picker.resolved_layout)
      if layout_config.preview == "main" or not picker.preview.win:valid() then
        return
      end

      local function find_preview(root)
        if root.win == "preview" then
          return root
        end
        for _, child in ipairs(root) do
          local preview = find_preview(child)
          if preview then
            return preview
          end
        end
      end

      local preview = find_preview(layout_config.layout)
      if not preview then
        return
      end

      local function eval(value)
        return type(value) == "function" and value(preview.win) or value
      end

      local width, height = eval(preview.width), eval(preview.height)
      if not width and not height then
        return
      end

      local sizes = { 0.1, 0.9 }
      local size_prop, size
      if height then
        size_prop, size = "height", height
      else
        size_prop, size = "width", width
      end

      picker.init_size = picker.init_size or size
      sizes[#sizes + 1] = picker.init_size
      table.sort(sizes)
      for i, current in ipairs(sizes) do
        if size == current then
          preview[size_prop] = sizes[i - 1] or sizes[#sizes]
          break
        end
      end

      for i, hidden in ipairs(layout_config.hidden) do
        if hidden == "preview" then
          table.remove(layout_config.hidden, i)
        end
      end
      picker:set_layout(layout_config)
    end
    local cycle_key = {
      "cycle_preview",
      desc = keybindings.picker.cyclePreview.desc,
      mode = keybindings.picker.cyclePreview.mode,
    }
    opts.picker.win.input.keys = vim.tbl_deep_extend("force", opts.picker.win.input.keys or {}, {
      [keybindings.picker.cyclePreview.shortcut] = cycle_key,
    })
    opts.picker.win.list.keys = vim.tbl_deep_extend("force", opts.picker.win.list.keys or {}, {
      [keybindings.picker.cyclePreview.shortcut] = cycle_key,
    })
  end,
}
