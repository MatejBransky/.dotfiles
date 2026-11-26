local keybindings = require("keybindings").snacks
local floatingExplorer = require("keybindings").explorer.floatingExplorer

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.explorer = opts.explorer or {}
    opts.explorer.replace_netrw = true

    opts.picker = opts.picker or {}
    opts.picker.sources = opts.picker.sources or {}
    local explorer = opts.picker.sources.explorer or {}
    explorer.hidden = true
    explorer.win = explorer.win or {}
    explorer.win.input = explorer.win.input or {}
    explorer.win.input.keys = vim.tbl_deep_extend("force", explorer.win.input.keys or {}, {
      [keybindings.picker.cancel.shortcut] = {
        "cancel",
        desc = keybindings.picker.cancel.desc,
        mode = keybindings.picker.cancel.mode,
      },
    })
    explorer.win.list = explorer.win.list or {}
    explorer.win.list.keys = vim.tbl_deep_extend("force", explorer.win.list.keys or {}, {
      [keybindings.explorer.setWorkingDirectory.shortcut] = {
        "tcd",
        desc = keybindings.explorer.setWorkingDirectory.desc,
        mode = keybindings.explorer.setWorkingDirectory.mode,
      },
      [keybindings.picker.cancel.shortcut] = {
        "cancel",
        desc = keybindings.picker.cancel.desc,
        mode = keybindings.picker.cancel.mode,
      },
    })
    opts.picker.sources.explorer = explorer
  end,
  keys = {
    {
      keybindings.explorer.show.shortcut,
      function()
        require("snacks").explorer({ auto_close = true })
      end,
      mode = keybindings.explorer.show.mode,
      desc = keybindings.explorer.show.desc,
    },
    {
      floatingExplorer.shortcut,
      function()
        require("snacks").explorer({
          cwd = LazyVim.root(),
          auto_close = true,
          layout = { preset = "default" },
        })
      end,
      mode = floatingExplorer.mode,
      desc = floatingExplorer.desc,
    },
  },
}
