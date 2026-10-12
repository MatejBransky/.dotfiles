local M = {}

local function git(root, args)
  local command = { "git", "-C", root }
  vim.list_extend(command, args)

  local result = vim.system(command, { text = false }):wait()
  if result.code ~= 0 then
    local message = vim.trim(result.stderr or "")
    return nil, message ~= "" and message or "Git command failed"
  end

  return result.stdout or ""
end

local function add_paths(files, output)
  for path in output:gmatch("([^%z]+)") do
    files[path] = true
  end
end

local function resolve_base(root, requested)
  local candidates = requested and { requested } or { "main", "origin/main", "origin/HEAD" }

  for _, candidate in ipairs(candidates) do
    local output = git(root, { "rev-parse", "--verify", "--quiet", candidate .. "^{commit}" })
    if output then
      return candidate
    end
  end

  return nil, "Could not find a main branch ref (tried main, origin/main, and origin/HEAD)"
end

---Collect files changed on the current branch and in the working tree.
---@param root string Git repository root
---@param requested_base? string Explicit base ref (defaults to main, then origin/main/origin/HEAD)
---@return string[]|nil files Sorted, unique paths relative to the repository root
---@return string? error
---@return string? base_ref
function M.changed_files(root, requested_base)
  local base_ref, base_error = resolve_base(root, requested_base)
  if not base_ref then
    return nil, base_error
  end

  local files = {}
  local commands = {
    { "diff", "--name-only", "-z", "--diff-filter=ACMR", base_ref .. "...HEAD", "--" },
    { "diff", "--name-only", "-z", "--diff-filter=ACMR", "--" },
    { "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR", "--" },
    { "ls-files", "--others", "--exclude-standard", "-z" },
  }

  for _, command in ipairs(commands) do
    local output, err = git(root, command)
    if not output then
      return nil, err
    end
    add_paths(files, output)
  end

  local result = {}
  for path in pairs(files) do
    -- Ignore files deleted from the working tree; git grep cannot search them.
    if vim.uv.fs_stat(vim.fs.joinpath(root, path)) then
      result[#result + 1] = path
    end
  end
  table.sort(result)

  return result, nil, base_ref
end

return M
