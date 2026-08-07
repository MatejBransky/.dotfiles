-- Configuration wrapper for lazygit.nvim's worktree synchronization support.
local M = {}
local active_timer
local augroup = vim.api.nvim_create_augroup("worktree_switcher", { clear = true })

---@class WorktreeSwitcher.Config
---@field enabled? boolean Enable synchronization from the LazyGit terminal.

M.config = { enabled = true }

local function normalize(path)
  path = vim.fn.fnamemodify(path, ":p")
  return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

local function is_worktree(path)
  if vim.fn.isdirectory(path) ~= 1 then
    return false
  end

  local result = vim.fn.system({ "git", "-C", path, "rev-parse", "--show-toplevel" })
  return vim.v.shell_error == 0 and normalize(result:gsub("%s+$", "")) == normalize(path)
end

local function set_session_cwd(path)
  local escaped = vim.fn.fnameescape(path)
  vim.cmd("cd " .. escaped)

  local current_tabpage = vim.api.nvim_get_current_tabpage()
  for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    vim.api.nvim_set_current_tabpage(tabpage)
    vim.cmd("tcd " .. escaped)
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      vim.api.nvim_win_call(win, function()
        vim.cmd("lcd " .. escaped)
      end)
    end
  end
  vim.api.nvim_set_current_tabpage(current_tabpage)
end

--- Return the terminal title used by the shell's tab-title hook.
---@param path string
---@return string
function M.terminal_title(path)
  local formatter = vim.env.HOME .. "/.config/zsh/tab-title-format"
  if vim.fn.executable(formatter) == 1 then
    local result = vim.fn.system({ formatter, path, "nvim" })
    if vim.v.shell_error == 0 then
      return vim.trim(result)
    end
  end
  return vim.fn.fnamemodify(path, ":~") .. "•nvim"
end

local function set_terminal_title(path)
  -- OSC 0 changes the title of terminal emulators such as WezTerm.
  vim.api.nvim_ui_send("\027]0;" .. M.terminal_title(path) .. "\007")
end

local function consume_new_dir(file)
  if vim.fn.filereadable(file) ~= 1 then
    return false
  end

  local lines = vim.fn.readfile(file)
  vim.fn.delete(file)
  if not lines[1] or lines[1] == "" then
    return false
  end

  return M.switch_to(lines[1])
end

--- Open LazyGit through Snacks while keeping its original LazyVim behavior.
---@param opts? table
---@return table terminal
function M.open_snacks(opts)
  opts = vim.deepcopy(opts or {})
  if not M.config.enabled then
    return Snacks.lazygit(opts)
  end

  local new_dir_file = vim.fn.tempname()
  local env = vim.fn.environ()
  env.LAZYGIT_NEW_DIR_FILE = new_dir_file
  opts.env = vim.tbl_deep_extend("force", opts.env or {}, env)

  local terminal = Snacks.lazygit(opts)
  active_timer = vim.uv.new_timer()
  active_timer:start(100, 100, vim.schedule_wrap(function()
    consume_new_dir(new_dir_file)
  end))

  terminal:on("TermClose", function()
    if active_timer then
      active_timer:stop()
      active_timer:close()
      active_timer = nil
    end
    consume_new_dir(new_dir_file)
    vim.fn.delete(new_dir_file)
  end, { buf = true })

  return terminal
end

--- Change the Neovim session cwd to an existing Git worktree.
---@param path string
---@return boolean changed
function M.switch_to(path)
  if type(path) ~= "string" or path == "" then
    return false
  end

  path = normalize(path)
  if not is_worktree(path) then
    vim.notify("Not a Git worktree: " .. path, vim.log.levels.WARN)
    return false
  end

  if normalize(vim.fn.getcwd()) == path then
    return true
  end

  set_session_cwd(path)
  set_terminal_title(path)
  vim.notify("Neovim cwd: " .. path, vim.log.levels.INFO)
  return true
end

--- Write the current cwd for the shell wrapper to consume after Neovim exits.
function M.write_exit_cwd()
  local file = vim.env.NVIM_CWD_FILE
  if file and file ~= "" then
    vim.fn.writefile({ vim.fn.getcwd() }, file)
  end
end

--- Configure worktree synchronization.
---@param opts? WorktreeSwitcher.Config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = M.write_exit_cwd,
  })
end

return M
