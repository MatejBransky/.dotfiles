local actions = require("telescope.actions")
local actions_layout = require("telescope.actions.layout")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local my_keys = require("my_keys")

local function filenameFirst(_, path)
  local tail = vim.fs.basename(path)
  local parent = vim.fs.dirname(path)
  if parent == "." then
    return tail
  end
  return string.format("%s\t\t%s", tail, parent)
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "TelescopeResults",
  callback = function(ctx)
    vim.api.nvim_buf_call(ctx.buf, function()
      vim.fn.matchadd("TelescopeParent", "\t\t.*$")
      vim.api.nvim_set_hl(0, "TelescopeParent", { link = "Comment" })
    end)
  end,
})

--- Switch from the 'recent_files' picker to the 'find_files' and vice versa
--- This action is meant to be used in recent_files and find_files
---@param prompt_bufnr number: The prompt bufnr
local action_narrow_scope = function(prompt_bufnr)
  local line = action_state.get_current_line()
  local opts = (function()
    local opts = {
      sorter = conf.generic_sorter({}),
    }

    local title = action_state.get_current_picker(prompt_bufnr).prompt_title
    if title == "Live Grep" then
      opts.prefix = "Refine"
    elseif title == "LSP Dynamic Workspace Symbols" then
      opts.prefix = "LSP Workspace Symbols"
      opts.sorter = conf.prefilter_sorter({
        tag = "symbol_type",
        sorter = opts.sorter,
      })
    else
      opts.prefix = "Fuzzy over"
    end

    return opts
  end)()

  require("telescope.actions.generate").refine(prompt_bufnr, {
    prompt_title = string.format('%s ("%s")', opts.prefix, line),
    sorter = opts.sorter,
  })
end

return {
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      {
        my_keys.telescope.findHiddenIncluded.shortcut,
        function()
          require("telescope.builtin").find_files({
            prompt_title = "Find files (hidden included)",
            hidden = true,
            no_ignore = true,
            no_ignore_parent = true,
            find_command = { "rg", "--files", "-g", "!{.git,node_modules,.gradle,tmp,dist,test-results}" },
          })
        end,
        desc = my_keys.telescope.findHiddenIncluded.desc,
      },
      {
        my_keys.telescope.showQuickfixLists.shortcut,
        function()
          require("telescope.builtin").quickfixhistory()
        end,
        desc = my_keys.telescope.showQuickfixLists.desc,
      },
      {
        my_keys.telescope.recentFiles.shortcut,
        function()
          local worktree = vim.fn.FugitiveWorkTree()
          local cwd = vim.fn.getcwd()

          return require("telescope").extensions.smart_open.smart_open({
            cwd = worktree ~= "" and worktree or cwd,
            cwd_only = true,
          })
        end,
        desc = my_keys.telescope.recentFiles.desc,
      },
      {
        my_keys.telescope.recentFilesCwd.shortcut,
        function()
          return require("telescope").extensions.smart_open.smart_open({
            cwd_only = true,
          })
        end,
        desc = my_keys.telescope.recentFilesCwd.desc,
      },
    },
    opts = {
      defaults = {
        -- show me the filename first
        path_display = filenameFirst,
        -- path_display = function(_, rawPath)
        --   local utils = require("telescope.utils")
        --   local tail = utils.path_tail(rawPath)
        --   local path = utils.transform_path({
        --     path_display = {
        --       absolute = 0,
        --     },
        --   }, rawPath)
        --   return string.format("%s -- %s", tail, path)
        -- end,

        mappings = {
          n = {
            [my_keys.telescope.togglePreview.shortcut] = actions_layout.toggle_preview,
            [my_keys.telescope.close.shortcut] = actions.close,
          },
          i = {
            [my_keys.telescope.openWindowPicker.shortcut] = function(prompt_bufnr)
              -- Use nvim-window-picker to choose the window by dynamically attaching a function
              local action_set = require("telescope.actions.set")
              local picker = action_state.get_current_picker(prompt_bufnr)

              picker.get_selection_window = function(picker)
                local picked_window_id = require("window-picker").pick_window() or vim.api.nvim_get_current_win()
                -- Unbind after using so next instance of the picker acts normally
                picker.get_selection_window = nil
                return picked_window_id
              end

              return action_set.edit(prompt_bufnr, "edit")
            end,
            [my_keys.telescope.togglePreview.shortcut] = actions_layout.toggle_preview,
          },
        },

        layout_strategy = "vertical",
      },
      pickers = {
        -- Sorts all buffers after most recent used.
        -- Not just the current and last one.
        buffers = {
          sort_mru = true,
        },
        -- prioritize file paths in the result (=> disable inline preview)
        -- https://github.com/nvim-telescope/telescope.nvim/issues/2121
        lsp_references = {
          show_line = false,
        },
        lsp_definitions = {
          show_line = false,
        },
        grep_string = {
          additional_args = { "--hidden" },
        },
        live_grep = {
          -- search in dotfiles/dotfolders
          additional_args = { "--hidden" },
          mappings = {
            i = {
              -- narrow grep search by the other search criteria (filename, extension, other word in the searched file)
              [my_keys.telescope.liveGrepFuzzyRefine.shortcut] = action_narrow_scope,
            },
          },
        },
      },
      extensions = {
        smart_open = {
          match_algorithm = "fzf",
        },
      },
    },
  },

  -- fuzzy finder prioritizing filenames and smartcase search
  {
    "natecraddock/telescope-zf-native.nvim",
    config = function()
      require("telescope").load_extension("zf-native")
    end,
  },

  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
  },

  {
    "MatejBransky/smart-open.nvim",
    config = function()
      require("telescope").load_extension("smart_open")
    end,
    dependencies = {
      "kkharji/sqlite.lua",
      -- Only required if using match_algorithm fzf
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      -- Optional. If installed, native fzy will be used when match_algorithm is fzy
      -- { "nvim-telescope/telescope-fzy-native.nvim" },
    },
  },
  -- text-case conversion
  {
    "johmsalas/text-case.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("textcase").setup({})
      require("telescope").load_extension("textcase")
    end,
    keys = {
      "ga", -- Default invocation prefix
      { "ga.", "<cmd>TextCaseOpenTelescope<CR>", mode = { "n", "x" }, desc = "Telescope" },
    },
    cmd = {
      -- NOTE: The Subs command name can be customized via the option "substitude_command_name"
      "Subs",
      "TextCaseOpenTelescope",
      "TextCaseOpenTelescopeQuickChange",
      "TextCaseOpenTelescopeLSPChange",
      "TextCaseStartReplacingCommand",
    },
    -- If you want to use the interactive feature of the `Subs` command right away, text-case.nvim
    -- has to be loaded on startup. Otherwise, the interactive feature of the `Subs` will only be
    -- available after the first executing of it or after a keymap of text-case.nvim has been used.
    lazy = false,
  },
}
