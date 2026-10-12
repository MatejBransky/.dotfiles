local features = require("config.snacks.features")
local keybindings = require("keybindings").snacks

if not features.picker_git_log_actions then
  return {}
end

local git_log = {
  actions = {
    open_file = function(picker)
      local commit = picker:current().commit
      picker:close()
      vim.cmd("Gitsigns show " .. commit)
    end,
    open_diffview = function(picker)
      local commit = picker:current().commit
      picker:close()
      vim.cmd("DiffviewOpen " .. commit .. "^.." .. commit)
    end,
  },
  win = {
    input = {
      keys = {
        [keybindings.gitLog.openFile.shortcut] = {
          "open_file",
          desc = keybindings.gitLog.openFile.desc,
          mode = keybindings.gitLog.openFile.mode,
        },
        [keybindings.gitLog.openDiffview.shortcut] = {
          "open_diffview",
          desc = keybindings.gitLog.openDiffview.desc,
          mode = keybindings.gitLog.openDiffview.mode,
        },
      },
    },
  },
}

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    opts.picker.sources = opts.picker.sources or {}
    opts.picker.sources.git_log = vim.tbl_deep_extend(
      "force",
      opts.picker.sources.git_log or {},
      git_log
    )
    opts.picker.sources.git_log_file = vim.tbl_deep_extend(
      "force",
      opts.picker.sources.git_log_file or {},
      git_log
    )
  end,
}
