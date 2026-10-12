---@module 'snacks'

local keybindings = require("keybindings").snacks

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    local picker = opts.picker
    picker.layouts = picker.layouts or {}
    picker.sources = picker.sources or {}

    picker.formatters = picker.formatters or {}
    picker.formatters.file = vim.tbl_deep_extend("force", picker.formatters.file or {}, {
      filename_first = true,
      truncate = 10000,
    })

    picker.layouts.dotfiles_dropdown = {
      layout = {
        backdrop = false,
        width = 0.8,
        min_width = 80,
        height = 0.8,
        border = "none",
        box = "vertical",
        {
          box = "vertical",
          border = "rounded",
          title = "{title} {live} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
        { win = "preview", title = "{preview}", height = 0.6, border = "rounded" },
      },
    }

    picker.sources.buffers = vim.tbl_deep_extend("force", picker.sources.buffers or {}, {
      layout = { preset = "select" },
      current = false,
    })
    picker.sources.grep = vim.tbl_deep_extend("force", picker.sources.grep or {}, {
      layout = { preset = "dotfiles_dropdown" },
    })
    picker.sources.lsp_references = vim.tbl_deep_extend("force", picker.sources.lsp_references or {}, {
      layout = { preset = "dotfiles_dropdown" },
    })
    picker.sources.smart = vim.tbl_deep_extend("force", picker.sources.smart or {}, {
      hidden = true,
      transform = function(item, ctx)
        if require("snacks.picker.transform").unique_file(item, ctx) == false then
          return false
        end
        item.buf_lastused = item.info and item.info.lastused or 0
      end,
      sort = {
        fields = { "buf_lastused:desc", "score:desc", "#text", "idx" },
      },
      filter = { cwd = true },
    })

    picker.win = picker.win or {}
    picker.win.input = picker.win.input or {}
    picker.win.input.keys = vim.tbl_deep_extend("force", picker.win.input.keys or {}, {
      ["<a-p>"] = false,
      [keybindings.picker.cancel.shortcut] = {
        "cancel",
        desc = keybindings.picker.cancel.desc,
        mode = keybindings.picker.cancel.mode,
      },
      [keybindings.picker.togglePreview.shortcut] = {
        "toggle_preview",
        desc = keybindings.picker.togglePreview.desc,
        mode = keybindings.picker.togglePreview.mode,
      },
    })
    picker.win.list = picker.win.list or {}
    picker.win.list.keys = vim.tbl_deep_extend("force", picker.win.list.keys or {}, {
      ["<a-p>"] = false,
      [keybindings.picker.togglePreview.shortcut] = {
        "toggle_preview",
        desc = keybindings.picker.togglePreview.desc,
        mode = keybindings.picker.togglePreview.mode,
      },
    })
  end,
  keys = {
    {
      keybindings.picker.findFiles.shortcut,
      function()
        require("snacks").picker.smart({ layout = "default" })
      end,
      mode = keybindings.picker.findFiles.mode,
      desc = keybindings.picker.findFiles.desc,
    },
    { "<leader>gi", false },
    { "<leader>gI", false },
    { "<leader>gp", false },
    { "<leader>gP", false },
    { "<leader>gf", false },
    { "<leader>gd", false },
  },
}
