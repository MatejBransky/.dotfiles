local features = require("config.snacks.features")

if not features.explorer_floating_preview then
  return {}
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    opts.picker.sources = opts.picker.sources or {}
    local explorer = opts.picker.sources.explorer or {}

    explorer.layout = { preset = "sidebar", preview = false }
    explorer.on_show = function(picker)
      local gap = 1
      local position = picker.resolved_layout.layout.position
      local root = picker.layout.root
      assert(
        position == "left" or position == "right",
        "Floating explorer preview requires a left/right sidebar layout"
      )

      local function update(win)
        local border = win:border_size().left + win:border_size().right
        win.opts.row = vim.api.nvim_win_get_position(root.win)[1]
        win.opts.height = 0.8
        if position == "left" then
          win.opts.col = vim.api.nvim_win_get_width(root.win) + gap
          win.opts.width = math.max(20, math.min(100, vim.o.columns - border - win.opts.col))
        else
          win.opts.col = -vim.api.nvim_win_get_width(root.win) - gap
          win.opts.width = math.max(20, math.min(100, vim.o.columns - border + win.opts.col))
        end
        win:update()
      end

      local preview_win = require("snacks").win.new({
        relative = "editor",
        external = false,
        focusable = false,
        border = "rounded",
        backdrop = false,
        show = false,
        bo = {
          filetype = "snacks_float_preview",
          buftype = "nofile",
          buflisted = false,
          swapfile = false,
          undofile = false,
        },
        on_win = function(win)
          update(win)
          picker:show_preview()
        end,
      })

      root:on("WinLeave", function()
        vim.schedule(function()
          if not picker:is_focused() then
            picker.preview.win:close()
          end
        end)
      end)
      root:on("WinResized", function()
        update(preview_win)
      end)

      picker.preview.win = preview_win
      picker.main = preview_win.win
    end
    explorer.on_close = function(picker)
      picker.preview.win:close()
    end
    explorer.actions = vim.tbl_deep_extend("force", explorer.actions or {}, {
      toggle_preview = function(picker)
        picker.preview.win:toggle()
      end,
    })
    opts.picker.sources.explorer = explorer
  end,
}
