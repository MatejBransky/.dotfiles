-- Tests for collecting branch and working-tree paths for the branch grep picker.
-- Run: nvim --headless -u NONE -l scripts/minitest.lua

package.path = vim.fn.stdpath("config") .. "/lua/?.lua;" .. package.path

local MiniTest = require("mini.test")
local T = MiniTest.new_set()
local branch_grep = require("libs.branch_grep")

local function git(root, ...)
  local args = { "git", "-C", root }
  vim.list_extend(args, { ... })
  local result = vim.system(args, { text = true }):wait()
  assert(result.code == 0, result.stderr)
  return result.stdout
end

local function write(root, path, content)
  local full_path = vim.fs.joinpath(root, path)
  vim.fn.mkdir(vim.fs.dirname(full_path), "p")
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), full_path)
end

local function new_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  git(root, "init", "--quiet", "-b", "main")
  git(root, "config", "user.name", "Branch grep test")
  git(root, "config", "user.email", "branch-grep@example.test")

  write(root, "branch-file.lua", "base")
  write(root, "staged-file.lua", "base")
  write(root, "unstaged-file.lua", "base")
  git(root, "add", ".")
  git(root, "commit", "--quiet", "-m", "base")
  git(root, "switch", "--quiet", "-c", "feature")

  write(root, "branch-file.lua", "branch change")
  write(root, "branch added.lua", "branch addition")
  git(root, "add", ".")
  git(root, "commit", "--quiet", "-m", "feature changes")

  return root
end

T["changed_files"] = MiniTest.new_set()

T["changed_files"]["includes branch changes and staged, unstaged, and untracked files"] = function()
  local root = new_repo()
  write(root, "staged-file.lua", "staged change")
  git(root, "add", "staged-file.lua")
  write(root, "unstaged-file.lua", "unstaged change")
  write(root, "new untracked.lua", "untracked addition")

  local files, err, base_ref = branch_grep.changed_files(root)

  MiniTest.expect.no_equality(files, nil)
  MiniTest.expect.equality(err, nil)
  MiniTest.expect.equality(base_ref, "main")
  MiniTest.expect.equality(files, {
    "branch added.lua",
    "branch-file.lua",
    "new untracked.lua",
    "staged-file.lua",
    "unstaged-file.lua",
  })

  vim.fn.delete(root, "rf")
end

T["changed_files"]["ignores files deleted from the working tree"] = function()
  local root = new_repo()
  vim.fn.delete(vim.fs.joinpath(root, "branch added.lua"))

  local files = branch_grep.changed_files(root)

  MiniTest.expect.equality(files, { "branch-file.lua" })
  vim.fn.delete(root, "rf")
end

T["changed_files"]["reports when no main ref is available"] = function()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  git(root, "init", "--quiet", "-b", "feature")

  local files, err = branch_grep.changed_files(root)

  MiniTest.expect.equality(files, nil)
  MiniTest.expect.equality(err, "Could not find a main branch ref (tried main, origin/main, and origin/HEAD)")
  vim.fn.delete(root, "rf")
end

return T
