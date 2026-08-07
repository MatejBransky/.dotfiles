-- Tests for worktree cwd synchronization configuration and API.
-- Run: nvim --headless -u NONE -l scripts/minitest.lua

package.path = vim.fn.stdpath("config") .. "/lua/?.lua;" .. package.path

local MiniTest = require("mini.test")
local T = MiniTest.new_set()
local switcher = require("libs.worktree_switcher")

local function new_dir()
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  return path
end

local function git_repo()
  local path = new_dir()
  vim.fn.system({ "git", "init", "--quiet", path })
  return path
end

T["switch_to"] = MiniTest.new_set()

T["switch_to"]["changes cwd to an existing worktree"] = function()
  local original = vim.fn.getcwd()
  local repo = git_repo()

  MiniTest.expect.equality(switcher.switch_to(repo), true)
  MiniTest.expect.equality(vim.fn.getcwd(), vim.uv.fs_realpath(repo))

  vim.fn.chdir(original)
  vim.fn.delete(repo, "rf")
end

T["switch_to"]["rejects a non-worktree directory"] = function()
  local original = vim.fn.getcwd()
  local directory = new_dir()

  MiniTest.expect.equality(switcher.switch_to(directory), false)
  MiniTest.expect.equality(vim.fn.getcwd(), original)

  vim.fn.delete(directory, "d")
end

T["switch_to"]["updates the current tab and window cwd"] = function()
  local original = vim.fn.getcwd()
  local repo = git_repo()
  vim.cmd("lcd " .. vim.fn.fnameescape(original))

  MiniTest.expect.equality(switcher.switch_to(repo), true)
  MiniTest.expect.equality(vim.fn.getcwd(), vim.uv.fs_realpath(repo))

  vim.fn.chdir(original)
  vim.fn.delete(repo, "rf")
end

T["config"] = MiniTest.new_set()

T["config"]["enables lazygit worktree synchronization"] = function()
  local original = switcher.config.enabled
  switcher.setup({ enabled = true })
  MiniTest.expect.equality(switcher.config.enabled, true)
  switcher.setup({ enabled = original })
end

T["exit cwd"] = MiniTest.new_set()

T["exit cwd"]["writes cwd when the shell provides a target file"] = function()
  local original_file = vim.env.NVIM_CWD_FILE
  local file = vim.fn.tempname()
  vim.env.NVIM_CWD_FILE = file

  switcher.write_exit_cwd()

  MiniTest.expect.equality(vim.fn.readfile(file), { vim.fn.getcwd() })

  vim.env.NVIM_CWD_FILE = original_file
  vim.fn.delete(file)
end

T["terminal title"] = MiniTest.new_set()

T["terminal title"]["uses a home-relative path"] = function()
  local home = vim.env.HOME
  MiniTest.expect.equality(switcher.terminal_title(home .. "/Developer/work/project"), "~/Developer/work/project•nvim")
end

T["terminal title"]["shares the formatter with zsh"] = function()
  local formatter = vim.env.HOME .. "/.config/zsh/tab-title-format"
  local result = vim.fn.system({ formatter, vim.env.HOME .. "/Developer/work/project", "nvim" })

  MiniTest.expect.equality(vim.v.shell_error, 0)
  MiniTest.expect.equality(vim.trim(result), switcher.terminal_title(vim.env.HOME .. "/Developer/work/project"))
end

T["terminal title"]["omits the command suffix for precmd titles"] = function()
  local formatter = vim.env.HOME .. "/.config/zsh/tab-title-format"
  local result = vim.fn.system({ formatter, vim.env.HOME .. "/Developer/work/project" })

  MiniTest.expect.equality(vim.v.shell_error, 0)
  MiniTest.expect.equality(vim.trim(result), "~/Developer/work/project")
end

return T
