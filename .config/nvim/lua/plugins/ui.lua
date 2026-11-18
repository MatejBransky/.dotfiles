local colorscheme_sync = require("libs.colorscheme_sync")

return {
  -- disable tabs
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },

  -- tsc (typescript-go) exits with code 1 even after a clean shutdown/exit, so
  -- every LSP restart shows a scary "Client tsc quit with exit code 1" warning.
  -- Hide that known false positive from notifications (the LSP log keeps it).
  -- https://github.com/microsoft/TypeScript/issues/64742
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      table.insert(opts.routes, {
        filter = { event = "notify", find = "^Client tsc quit with exit code" },
        opts = { skip = true },
      })
    end,
  },

  -- Scrollbar
  {
    "petertriho/nvim-scrollbar",
    branch = "refactor/v2",
    event = "BufReadPost",
    opts = {
      exclude = {
        filetypes = {
          notify = true,
          ["neo-tree"] = true,
        },
      },
      providers = {
        gitsigns = true,
      },
    },
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
