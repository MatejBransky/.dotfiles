local colorscheme_sync = require("libs.colorscheme_sync")

return {
  -- disable tabs
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },

  -- Scrollbar
  {
    "petertriho/nvim-scrollbar",
    event = "BufReadPost",
    opts = {
      excluded_filetypes = { "prompt", "TelescopePrompt", "noice", "notify", "neo-tree" },
      handlers = {
        -- cursor = false,
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    opts = function()
      require("scrollbar.handlers.gitsigns").setup()
    end,
  },

  {
    "folke/flash.nvim",
    keys = {
      {
        "<c-space>",
        mode = { "n", "o", "x" },
        function()
          require("flash").treesitter({
            labels = "123456789",
            actions = {
              ["<c-space>"] = "next",
              ["<BS>"] = "prev",
            },
          })
        end,
        desc = "Treesitter Incremental Selection",
      },
    },
  },

  {
    "typicode/bg.nvim",
    lazy = false,
    config = function()
      colorscheme_sync.watch_theme_changes()
      colorscheme_sync.watch_config_changes()
    end,
  },
}
