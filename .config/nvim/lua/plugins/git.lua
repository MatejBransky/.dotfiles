local keybindings = require("keybindings")

---Close diffview completely, then open the file selected in it in its place.
---
---Diffview's own <C-w>gf keeps the view open, which makes the opened buffer
---shared with the diff window, so closing it afterwards tears down diffview.
---@return nil
local function diffview_close_and_goto_file()
  local lib = require("diffview.lib")
  local view = lib.get_current_view()

  if not view then
    vim.notify("No diffview open", vim.log.levels.WARN)
    return
  end

  local file = view:infer_cur_file()
  if not file then
    vim.notify("No file selected", vim.log.levels.WARN)
    return
  end

  if not require("diffview.utils").path:readable(file.absolute_path) then
    vim.notify("File does not exist on disk: " .. file.absolute_path, vim.log.levels.WARN)
    return
  end

  local path = file.absolute_path
  local layout = file.layout
  local cursor
  local main = view.cur_layout:get_main_win()
  if main:is_valid() and vim.api.nvim_win_get_buf(main.id) == file.bufnr then
    cursor = vim.api.nvim_win_get_cursor(main.id)
  end

  vim.cmd("DiffviewClose")
  layout:restore_winopts()
  vim.cmd("edit " .. vim.fn.fnameescape(path))

  if cursor then
    pcall(vim.api.nvim_win_set_cursor, 0, cursor)
  end
end

return {
  {
    "worktree-switcher",
    dir = vim.fn.stdpath("config") .. "/lua/libs/worktree_switcher",
    lazy = false,
    main = "libs.worktree_switcher",
    opts = { enabled = true },
    keys = {
      {
        "<leader>gg",
        function()
          require("libs.worktree_switcher").open_snacks({ cwd = LazyVim.root.git() })
        end,
        desc = "Lazygit (Root Dir)",
      },
      {
        "<leader>gD",
        function()
          Snacks.lazygit({
            cwd = vim.env.HOME,
            args = { "--git-dir=" .. vim.env.HOME .. "/.cfg", "--work-tree=" .. vim.env.HOME },
          })
        end,
        desc = "Lazygit (Dotfiles)",
      },
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gg", false },
      {
        keybindings.git.grepBranchFiles.shortcut,
        function()
          local root = LazyVim.root.git()
          if not root then
            vim.notify("Not inside a Git repository", vim.log.levels.WARN)
            return
          end

          local files, err, base_ref = require("libs.branch_grep").changed_files(root)
          if not files then
            vim.notify(err, vim.log.levels.ERROR)
            return
          end
          if #files == 0 then
            vim.notify("No changed files against " .. base_ref .. " or in the working tree", vim.log.levels.INFO)
            return
          end

          local pathspec = vim.tbl_map(function(file)
            return ":(literal)" .. file
          end, files)

          Snacks.picker.git_grep({ cwd = root, pathspec = pathspec, untracked = true })
        end,
        mode = keybindings.git.grepBranchFiles.mode,
        desc = keybindings.git.grepBranchFiles.desc,
      },
    },
  },
  { "tpope/vim-rhubarb" }, -- github support for vim-fugitive
  {
    "tpope/vim-fugitive",
    config = function()
      local reference = require("libs.code_notes.reference")

      vim.keymap.set(keybindings.references.copyFilepath.mode, keybindings.references.copyFilepath.shortcut, function()
        vim.fn.setreg("*", reference.relative_path())
      end, { desc = keybindings.references.copyFilepath.desc, silent = true })

      vim.keymap.set(keybindings.references.copyBufferName.mode, keybindings.references.copyBufferName.shortcut, function()
        local buffer_name = vim.fn.expand("%:t")
        if buffer_name == "" then
          buffer_name = vim.fn.bufname()
        end
        vim.fn.setreg("*", buffer_name)
        vim.notify("Copied: " .. buffer_name, vim.log.levels.INFO)
      end, { desc = keybindings.references.copyBufferName.desc, silent = true })

      vim.keymap.set(keybindings.references.copyLineRef.mode, keybindings.references.copyLineRef.shortcut, function()
        local ref = reference.line_ref()
        vim.fn.setreg("*", ref)
        vim.notify("Copied: " .. ref, vim.log.levels.INFO)
      end, { desc = keybindings.references.copyLineRef.desc, silent = true })

      vim.keymap.set(
        keybindings.references.openInBrowser.mode,
        keybindings.references.openInBrowser.shortcut,
        "<Cmd>GBrowse<CR>",
        { desc = keybindings.references.openInBrowser.desc }
      )

      vim.keymap.set(
        keybindings.references.copyFileLink.mode,
        keybindings.references.copyFileLink.shortcut,
        "<Cmd>GBrowse!<CR>",
        { desc = keybindings.references.copyFileLink.desc }
      )

      vim.keymap.set(
        keybindings.references.copyLineLink.mode,
        keybindings.references.copyLineLink.shortcut,
        function()
          local from, to = reference.line_range()
          if from == to then
            vim.cmd(from .. "GBrowse!")
          else
            vim.cmd(from .. "," .. to .. "GBrowse!")
          end
        end,
        { desc = keybindings.references.copyLineLink.desc, silent = true }
      )

      vim.keymap.set(
        keybindings.git.fastForward.mode,
        keybindings.git.fastForward.shortcut,
        "<Cmd>G pull --ff-only<CR>",
        { desc = keybindings.git.fastForward.desc }
      )
    end,
  },
  {
    "sindrets/diffview.nvim",
    -- INFO: this allows me to open nvim in the diffview mode immediately (nvim -c DiffviewOpen)
    cmd = { "DiffviewOpen" },
    opts = {
      view = {
        merge_tool = {
          layout = "diff3_mixed",
        },
      },
      keymaps = {
        view = {
          {
            "n",
            keybindings.git.openCommitFile.shortcut,
            function()
              local view = require("diffview.lib").get_current_view()
              if not view then
                vim.notify("No diffview open", vim.log.levels.WARN)
                return
              end

              local rev = view.left
              if not rev or not rev.commit then
                vim.notify("No commit revision found", vim.log.levels.WARN)
                return
              end

              local file = view.panel.cur_file
              if not file then
                vim.notify("No file selected", vim.log.levels.WARN)
                return
              end

              vim.cmd("tabnew")
              vim.cmd("keepalt Gedit " .. rev.commit .. ":" .. file.path)
            end,
            { desc = keybindings.git.openCommitFile.desc, silent = true },
          },
          {
            "n",
            keybindings.git.closeDiffviewAndOpenFile.shortcut,
            diffview_close_and_goto_file,
            { desc = keybindings.git.closeDiffviewAndOpenFile.desc, silent = true },
          },
        },
        file_panel = {
          {
            "n",
            keybindings.git.openCommitFile.shortcut,
            function()
              local view = require("diffview.lib").get_current_view()
              if not view then
                vim.notify("No diffview open", vim.log.levels.WARN)
                return
              end

              local rev = view.left
              if not rev or not rev.commit then
                vim.notify("No commit revision found", vim.log.levels.WARN)
                return
              end

              local file = view.panel:get_item_at_cursor()
              if not file or not file.path then
                vim.notify("No file selected", vim.log.levels.WARN)
                return
              end

              vim.cmd("tabnew")
              vim.cmd("keepalt Gedit " .. rev.commit .. ":" .. file.path)
            end,
            { desc = keybindings.git.openCommitFile.desc, silent = true },
          },
          {
            "n",
            keybindings.git.closeDiffviewAndOpenFile.shortcut,
            diffview_close_and_goto_file,
            { desc = keybindings.git.closeDiffviewAndOpenFile.desc, silent = true },
          },
        },
        file_history_panel = {
          {
            "n",
            keybindings.git.openCommitFile.shortcut,
            function()
              local view = require("diffview.lib").get_current_view()
              if not view then
                vim.notify("No diffview open", vim.log.levels.WARN)
                return
              end

              local entry = view.panel:get_log_entry_at_cursor()
              if not entry or not entry.commit then
                vim.notify("No commit selected", vim.log.levels.WARN)
                return
              end

              local hash = entry.commit.hash
              local file = entry.files[1]
              if not hash or not file then
                vim.notify("Cannot determine commit or file", vim.log.levels.WARN)
                return
              end

              vim.cmd("tabnew")
              vim.cmd("keepalt Gedit " .. hash .. ":" .. file.path)
            end,
            { desc = keybindings.git.openCommitFile.desc, silent = true },
          },
          {
            "n",
            keybindings.git.closeDiffviewAndOpenFile.shortcut,
            diffview_close_and_goto_file,
            { desc = keybindings.git.closeDiffviewAndOpenFile.desc, silent = true },
          },
        },
      },
    },
    keys = {
      {
        keybindings.git.branchHistory.shortcut,
        "<Cmd>DiffviewFileHistory<CR>",
        desc = keybindings.git.branchHistory.desc,
      },
      {
        keybindings.git.fileHistory.shortcut,
        "<Cmd>DiffviewFileHistory --no-merges %<CR>",
        desc = keybindings.git.fileHistory.desc,
      },
      { keybindings.git.closeHistory.shortcut, ":tabclose<CR>", desc = keybindings.git.closeHistory.desc },
      {
        keybindings.git.uncommitedChanges.shortcut,
        "<Cmd>DiffviewOpen --imply-local<CR>",
        desc = keybindings.git.uncommitedChanges.desc,
      },
      { keybindings.git.review.shortcut, "<Cmd>DiffviewOpen origin/", desc = keybindings.git.review.desc },
      {
        keybindings.git.branchChanges.shortcut,
        "<Cmd>DiffviewOpen origin/HEAD...HEAD<CR>",
        desc = keybindings.git.branchChanges.desc,
      },
      {
        keybindings.git.traceLineEvolution.shortcut,
        "<Cmd>'<,'>DiffviewFileHistory<CR>",
        desc = keybindings.git.traceLineEvolution.desc,
        mode = keybindings.git.traceLineEvolution.mode,
      },
      {
        "<M-Left>",
        function()
          require("diffview.actions").prev_conflict()
        end,
        { desc = "In the merge-tool: jump to the prev conflict" },
      },
      {
        "<M-Right>",
        function()
          require("diffview.actions").next_conflict()
        end,
        { desc = "In the merge-tool: jump to the next conflict" },
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    keys = {
      {
        "<leader>gl",
        function()
          require("gitsigns.actions").toggle_current_line_blame()
        end,
        desc = "Toggle current line blame",
      },
    },
  },
}
