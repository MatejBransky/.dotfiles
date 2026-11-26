-- Import graph primitives: parse import statements, resolve them to files and
-- find the files that import a given file.
--
-- This module is UI agnostic so it can be tested without Snacks and reused by
-- other pickers. The Snacks picker lives in lua/plugins/snacks/explorer_import_graph.lua.

local M = {}

local uv = vim.uv or vim.loop

---@class ImportGraph.Import
---@field spec string
---@field line number
---@field kind "import"|"require"|"dynamic"|"side-effect"|"lua"

---@class ImportGraph.Entry
---@field file? string
---@field external? string
---@field spec? string
---@field line? number
---@field kind? string

local JS_EXT = {
  ".ts",
  ".tsx",
  ".mts",
  ".cts",
  ".js",
  ".jsx",
  ".mjs",
  ".cjs",
  ".vue",
  ".svelte",
  ".json",
}

local JS_EXT_ALIASES = {
  js = { "ts", "tsx" },
  jsx = { "tsx", "ts" },
  mjs = { "mts", "ts" },
  cjs = { "cts", "ts" },
}

local LANGS = {
  ts = "js",
  tsx = "js",
  mts = "js",
  cts = "js",
  js = "js",
  jsx = "js",
  mjs = "js",
  cjs = "js",
  vue = "js",
  svelte = "js",
  lua = "lua",
}

--- Detect the import language for a file.
---@param file string
---@return "js"|"lua"|nil
function M.lang(file)
  local ext = file:match("%.([%w]+)$")
  return ext and LANGS[ext] or nil
end

local function is_file(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

local function is_dir(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

local function normalize(path)
  return vim.fs.normalize(path):gsub("/+$", "")
end

local function dedupe(list)
  local seen, ret = {}, {}
  for _, value in ipairs(list) do
    if value ~= "" and not seen[value] then
      seen[value] = true
      ret[#ret + 1] = value
    end
  end
  return ret
end

--- Project root used for resolving modules and scanning for importers.
---@param file string
---@return string
function M.root(file)
  file = normalize(file)

  if M.lang(file) == "lua" then
    local dir = vim.fs.dirname(file)
    while dir and dir ~= "/" do
      if vim.fs.basename(dir) == "lua" and is_dir(dir) then
        return vim.fs.dirname(dir)
      end
      local parent = vim.fs.dirname(dir)
      if parent == dir then
        break
      end
      dir = parent
    end
  end

  return vim.fs.root(file, { ".git", "package.json", "tsconfig.json", "jsconfig.json" })
    or vim.fs.dirname(file)
end

local file_cache = {}
local tsconfig_cache = {}
local dependents_cache = {}
local DEPENDENTS_TTL = 300 -- seconds; `R` in the picker forces a rescan

--- Read a file, reusing the cached content while the file is unchanged.
---@param path string
---@return string|nil
function M.read(path)
  local stat = uv.fs_stat(path)
  if not stat or stat.type ~= "file" then
    return nil
  end

  local cached = file_cache[path]
  if cached and cached.mtime == stat.mtime.sec and cached.size == stat.size then
    return cached.text
  end

  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)

  local text = data or ""
  file_cache[path] = { mtime = stat.mtime.sec, size = stat.size, text = text }
  return text
end

--- Drop cached file contents, tsconfig data and importer scans.
function M.clear_cache()
  file_cache = {}
  tsconfig_cache = {}
  dependents_cache = {}
end

--- Strip JS/TS comments while preserving strings and newlines.
---@param text string
---@return string
local function strip_js_comments(text)
  local out = {}
  local i, len = 1, #text
  local quote

  while i <= len do
    local char = text:sub(i, i)
    if quote then
      out[#out + 1] = char
      if char == "\\" then
        out[#out + 1] = text:sub(i + 1, i + 1)
        i = i + 2
      else
        if char == quote then
          quote = nil
        end
        i = i + 1
      end
    elseif char == '"' or char == "'" or char == "`" then
      quote = char
      out[#out + 1] = char
      i = i + 1
    elseif char == "/" and text:sub(i + 1, i + 1) == "/" then
      i = text:find("\n", i, true) or len + 1
    elseif char == "/" and text:sub(i + 1, i + 1) == "*" then
      local close = text:find("*/", i + 2, true)
      if close then
        out[#out + 1] = text:sub(i, close + 1):gsub("[^\n]", "")
        i = close + 2
      else
        i = len + 1
      end
    else
      out[#out + 1] = char
      i = i + 1
    end
  end

  return table.concat(out)
end

--- Strip Lua line comments while preserving strings and newlines.
---@param text string
---@return string
local function strip_lua_comments(text)
  local out = {}
  local i, len = 1, #text
  local quote

  while i <= len do
    local char = text:sub(i, i)
    if quote then
      out[#out + 1] = char
      if char == "\\" then
        out[#out + 1] = text:sub(i + 1, i + 1)
        i = i + 2
      else
        if char == quote then
          quote = nil
        end
        i = i + 1
      end
    elseif char == '"' or char == "'" then
      quote = char
      out[#out + 1] = char
      i = i + 1
    elseif char == "-" and text:sub(i + 1, i + 1) == "-" then
      i = text:find("\n", i, true) or len + 1
    else
      out[#out + 1] = char
      i = i + 1
    end
  end

  return table.concat(out)
end

local PARSERS = {}

---@param text string
---@return ImportGraph.Import[]
function PARSERS.js(text)
  local out, seen = {}, {}
  local line = 0

  local function add(spec, kind, lnum)
    spec = vim.trim(spec)
    if spec == "" then
      return
    end
    local key = kind .. "\0" .. spec .. "\0" .. lnum
    if seen[key] then
      return
    end
    seen[key] = true
    out[#out + 1] = { spec = spec, line = lnum, kind = kind }
  end

  for current in (strip_js_comments(text) .. "\n"):gmatch("(.-)\n") do
    line = line + 1
    for spec in current:gmatch("from%s*['\"]([^'\"]+)['\"]") do
      add(spec, "import", line)
    end
    for spec in current:gmatch("require%s*%(%s*['\"]([^'\"]+)['\"]%s*%)") do
      add(spec, "require", line)
    end
    for spec in current:gmatch("import%s*%(%s*['\"]([^'\"]+)['\"]%s*%)") do
      add(spec, "dynamic", line)
    end
    -- gmatch does not support the `^` anchor, so use match here
    local side_effect = current:match("^%s*import%s*['\"]([^'\"]+)['\"]")
    if side_effect then
      add(side_effect, "side-effect", line)
    end
  end

  return out
end

---@param text string
---@return ImportGraph.Import[]
function PARSERS.lua(text)
  local out, seen = {}, {}
  local line = 0

  for current in (strip_lua_comments(text) .. "\n"):gmatch("(.-)\n") do
    line = line + 1
    for spec in current:gmatch("require%s*%(?%s*['\"]([^'\"]+)['\"]") do
      local key = spec .. "\0" .. line
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = { spec = spec, line = line, kind = "lua" }
      end
    end
  end

  return out
end

--- Parse all imports in a source text.
---@param text string
---@param lang "js"|"lua"|string
---@return ImportGraph.Import[]
function M.parse(text, lang)
  local parser = PARSERS[lang]
  return parser and parser(text) or {}
end

--- Read a JSONC file (JSON with comments and trailing commas).
---@param path string
---@return table|nil
local function read_jsonc(path)
  local text = M.read(path)
  if not text then
    return nil
  end

  local cleaned = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("^%s*//.*$", "")
    line = line:gsub("%s//.*$", "")
    cleaned[#cleaned + 1] = line
  end

  local text = table.concat(cleaned, "\n"):gsub(",%s*([}%]])", "%1")
  local decoded, data = pcall(vim.json.decode, text)
  return decoded and data or nil
end

--- Load the paths/baseUrl entries of a tsconfig, following relative `extends`.
---@param path string
---@param seen? table<string, boolean>
---@return { entries: table[], base_url?: string }|nil
local function load_tsconfig(path, seen)
  path = normalize(path)
  seen = seen or {}

  if seen[path] then
    return nil
  end
  seen[path] = true

  if tsconfig_cache[path] ~= nil then
    return tsconfig_cache[path] or nil
  end

  local data = read_jsonc(path)
  if not data then
    tsconfig_cache[path] = false
    return nil
  end

  local dir = vim.fs.dirname(path)
  local base_url
  local entries = {}

  local extends = data.extends
  if type(extends) == "string" then
    extends = { extends }
  end

  for _, ext in ipairs(extends or {}) do
    if type(ext) == "string" and (ext:sub(1, 1) == "." or ext:sub(1, 1) == "/") then
      local parent = normalize(dir .. "/" .. ext)
      if not parent:match("%.json$") then
        parent = parent .. ".json"
      end
      local inherited = load_tsconfig(parent, seen)
      if inherited then
        base_url = base_url or inherited.base_url
        vim.list_extend(entries, inherited.entries)
      end
    end
  end

  local compiler = data.compilerOptions or {}
  if compiler.baseUrl then
    base_url = normalize(dir .. "/" .. compiler.baseUrl)
  end

  for pattern, targets in pairs(compiler.paths or {}) do
    if type(targets) == "string" then
      targets = { targets }
    end
    entries[#entries + 1] = {
      pattern = pattern,
      targets = targets,
      base = base_url or dir,
    }
  end

  table.sort(entries, function(a, b)
    return #a.pattern > #b.pattern
  end)

  local config = { entries = entries, base_url = base_url }
  tsconfig_cache[path] = config
  return config
end

--- Find the nearest tsconfig.json for a file, not going above the project root.
---@param file string
---@param root string
---@return string|nil
local function find_tsconfig(file, root)
  local dir = vim.fs.dirname(file)
  while dir do
    local path = dir .. "/tsconfig.json"
    if is_file(path) then
      return path
    end
    if dir == root or #dir <= #root then
      break
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

---@param pattern string
---@param spec string
---@return string|nil
local function match_pattern(pattern, spec)
  local prefix, suffix = pattern:match("^(.-)%*(.*)$")
  if not prefix then
    return pattern == spec and "" or nil
  end
  if #spec < #prefix + #suffix then
    return nil
  end
  if spec:sub(1, #prefix) ~= prefix then
    return nil
  end
  if #suffix > 0 and spec:sub(-#suffix) ~= suffix then
    return nil
  end
  return spec:sub(#prefix + 1, #spec - #suffix)
end

--- Probe a JS/TS module base path for a real file.
---@param base string
---@return string|nil
local function probe_js(base)
  base = normalize(base)

  if is_file(base) then
    return base
  end

  local candidates = { base }

  -- TypeScript lets `./foo.js` refer to `./foo.ts`.
  local ext = base:match("%.([%w]+)$")
  if ext and JS_EXT_ALIASES[ext] then
    local stem = base:sub(1, #base - #ext - 1)
    candidates[#candidates + 1] = stem
    for _, alias in ipairs(JS_EXT_ALIASES[ext]) do
      local path = stem .. "." .. alias
      if is_file(path) then
        return path
      end
    end
  end

  for _, candidate in ipairs(candidates) do
    for _, suffix in ipairs(JS_EXT) do
      local path = candidate .. suffix
      if is_file(path) then
        return path
      end
    end
    for _, suffix in ipairs(JS_EXT) do
      local path = candidate .. "/index" .. suffix
      if is_file(path) then
        return path
      end
    end
  end
end

---@param spec string
---@param file string
---@param root string
---@return string|nil
local function resolve_alias(spec, file, root)
  local tsconfig = find_tsconfig(file, root)
  if not tsconfig then
    return nil
  end

  local config = load_tsconfig(tsconfig)
  if not config then
    return nil
  end

  for _, entry in ipairs(config.entries) do
    local match = match_pattern(entry.pattern, spec)
    if match then
      for _, target in ipairs(entry.targets) do
        local replaced = target:gsub("%*", match)
        local resolved = probe_js(normalize(entry.base .. "/" .. replaced))
        if resolved then
          return resolved
        end
      end
    end
  end
end

---@param value any
---@return string|nil
local function first_string(value)
  if type(value) == "string" then
    return value
  end
  if type(value) == "table" then
    for _, key in ipairs({ "types", "import", "module", "require", "default", "node" }) do
      local found = first_string(value[key])
      if found then
        return found
      end
    end
    for _, item in ipairs(value) do
      local found = first_string(item)
      if found then
        return found
      end
    end
  end
end

--- Resolve a subpath through a package.json `exports` map.
---@param json table
---@param sub string
---@return string|nil
local function package_target(json, sub)
  local exports = json.exports
  if exports == nil then
    return sub == "" and (json.module or json.main) or ("./" .. sub)
  end
  if type(exports) == "string" then
    return exports
  end
  if type(exports) ~= "table" then
    return nil
  end

  local wanted = sub == "" and "." or ("./" .. sub)
  local direct = first_string(exports[wanted])
  if direct then
    return direct
  end

  for pattern, value in pairs(exports) do
    if type(pattern) == "string" and pattern:find("*", 1, true) then
      local capture = match_pattern(pattern, wanted)
      if capture then
        local target = first_string(value)
        if target then
          return (target:gsub("%*", capture))
        end
      end
    end
  end

  if sub == "" then
    -- Condition-only exports map (e.g. `{ "import": "./index.js" }`), as
    -- opposed to subpath exports (keys starting with ".").
    for key in pairs(exports) do
      if type(key) == "string" and key:sub(1, 1) == "." then
        return nil
      end
    end
    return first_string(exports)
  end
end

--- Find a node_modules package directory, walking up from the importing file.
---@param name string
---@param file string
---@param root string
---@return string|nil
local function find_package_dir(name, file, root)
  local dir = vim.fs.dirname(file)
  while dir do
    local candidate = normalize(dir .. "/node_modules/" .. name)
    if is_file(candidate .. "/package.json") then
      return candidate
    end
    if dir == root or #dir <= #root then
      break
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end

  local fallback = normalize(root .. "/node_modules/" .. name)
  if is_file(fallback .. "/package.json") then
    return fallback
  end
end

--- Resolve a bare specifier through node_modules and package.json exports.
---@param spec string
---@param file string
---@param root string
---@return string|nil
local function resolve_package(spec, file, root)
  local name, sub
  if spec:sub(1, 1) == "@" then
    name, sub = spec:match("^(@[^/]+/[^/]+)/?(.*)$")
  else
    name, sub = spec:match("^([^/]+)/?(.*)$")
  end
  sub = sub or ""
  if not name or name == "" then
    return nil
  end

  local dir = find_package_dir(name, file, root)
  if not dir then
    return nil
  end

  local json = read_jsonc(dir .. "/package.json")
  if not json then
    return nil
  end

  local target = package_target(json, sub)
  if not target then
    return nil
  end

  local resolved = probe_js(normalize(dir .. "/" .. target))
  if resolved then
    -- node_modules entries are often symlinks to workspace packages
    resolved = uv.fs_realpath(resolved) or resolved
    -- Dependencies stay external unless they resolve to real project files;
    -- this keeps `react` or `next/image` out of the graph while monorepo
    -- workspace packages (symlinked into node_modules) are included.
    if resolved:find("/node_modules/", 1, true) then
      return nil
    end
    return resolved
  end
end

---@param spec string
---@param file string
---@param root string
---@return string|nil
local function resolve_js(spec, file, root)
  spec = spec:gsub("[?#].*$", "")
  if spec == "" then
    return nil
  end

  if spec:sub(1, 1) == "." then
    return probe_js(normalize(vim.fs.dirname(file) .. "/" .. spec))
  end
  if spec:sub(1, 1) == "/" then
    return probe_js(spec)
  end

  return resolve_alias(spec, file, root) or resolve_package(spec, file, root)
end

---@param spec string
---@param root string
---@return string|nil
local function resolve_lua(spec, root)
  local module = spec:gsub("%.", "/"):gsub("^lua/", "")
  local candidates = {
    root .. "/lua/" .. module .. ".lua",
    root .. "/lua/" .. module .. "/init.lua",
    root .. "/" .. module .. ".lua",
    root .. "/" .. module .. "/init.lua",
  }
  for _, candidate in ipairs(candidates) do
    if is_file(candidate) then
      return normalize(candidate)
    end
  end
end

--- Resolve a single import specifier.
---@param spec string
---@param file string
---@param opts? { root?: string, lang?: "js"|"lua" }
---@return ImportGraph.Entry
function M.resolve(spec, file, opts)
  opts = opts or {}
  file = normalize(file)

  local lang = opts.lang or M.lang(file)
  local root = opts.root or M.root(file)

  if lang == "lua" then
    local resolved = resolve_lua(spec, root)
    return resolved and { file = resolved } or {}
  end

  if lang == "js" then
    local resolved = resolve_js(spec, file, root)
    if resolved then
      return { file = resolved }
    end
    -- Unresolved relative or alias imports are local, but broken. Bare
    -- specifiers are external packages worth showing in the graph.
    if not spec:match("^%.") and not spec:match("^/") and not spec:match("^[@~#]/") then
      return { external = spec }
    end
    return {}
  end

  return {}
end

--- Resolve all imports of a file.
---@param file string
---@param opts? { root?: string, text?: string }
---@return ImportGraph.Entry[]
function M.dependencies(file, opts)
  opts = opts or {}
  file = normalize(file)

  local lang = M.lang(file)
  if not lang then
    return {}
  end

  local text = opts.text or M.read(file)
  if not text then
    return {}
  end

  local root = opts.root or M.root(file)
  local out, seen_files, seen_external = {}, {}, {}

  for _, import in ipairs(M.parse(text, lang)) do
    local entry = M.resolve(import.spec, file, { root = root, lang = lang })
    if entry.file then
      if not seen_files[entry.file] then
        seen_files[entry.file] = true
        out[#out + 1] = {
          file = entry.file,
          spec = import.spec,
          line = import.line,
          kind = import.kind,
        }
      end
    elseif entry.external then
      if not seen_external[entry.external] then
        seen_external[entry.external] = true
        out[#out + 1] = {
          external = entry.external,
          spec = import.spec,
          line = import.line,
          kind = import.kind,
        }
      end
    end
  end

  return out
end

--- Search terms likely to appear in imports of `file`.
---@param file string
---@param root string
---@param lang "js"|"lua"|string
---@return string[]
function M.terms(file, root, lang)
  local rel = vim.fs.relpath(root, file)
  if not rel then
    return {}
  end
  rel = rel:gsub("\\", "/")

  if lang == "lua" then
    local module = rel:gsub("%.lua$", ""):gsub("^lua/", ""):gsub("/init$", ""):gsub("/", ".")
    local module_path = module:gsub("%.", "/")
    return dedupe({ module, module_path })
  end

  local noext = rel:gsub("%.[%w]+$", ""):gsub("%.d$", "")
  local base = vim.fs.basename(noext)

  -- Every specifier that points at a file ends with the file basename as a
  -- path segment (`./Button`, `../Button`, `@/ui/Button`, `pkg/Button`).
  -- Searching for "/Button" is therefore both complete and much more
  -- selective than searching for "Button" (which also matches `ButtonProps`).
  if base == "index" then
    local dir = vim.fs.basename(vim.fs.dirname(noext))
    if dir ~= "" and dir ~= "." then
      return { "/" .. dir }
    end
    return { "/" .. noext }
  end

  return { "/" .. base }
end

--- Default synchronous ripgrep runner.
---@param cmd string[]
---@param cwd string
---@return string|nil
function M.run(cmd, cwd)
  if vim.fn.executable(cmd[1]) ~= 1 then
    return nil
  end

  local ok, result = pcall(vim.system, cmd, { text = true, cwd = cwd })
  if not ok then
    return nil
  end
  local out = result:wait()
  if out.code ~= 0 and out.code ~= 1 then
    return nil
  end
  return out.stdout
end

--- Escape a literal string for use in a ripgrep (Rust regex) pattern.
---@param term string
---@return string
local function regex_escape(term)
  return (term:gsub("([%.%+%-%*%?%[%]%^%$%(%)%{%}%|\\])", "\\%1"))
end

--- Build a ripgrep pattern that only matches import-like lines referring to `term`.
---@param term string
---@return string
local function import_pattern(term)
  return ("(?:from|import|require)\\s*\\(?\\s*[\"'][^\"']*" .. regex_escape(term) .. "[^\"']*[\"']")
end

--- Find import lines that may refer to `file`, without reading whole files.
---@param terms string[]
---@param root string
---@param lang "js"|"lua"|string
---@param opts? { run?: fun(cmd: string[], cwd: string): string|nil, max_lines?: number }
---@return { file: string, line: number, text: string }[]
function M.scan_lines(terms, root, lang, opts)
  opts = opts or {}
  if #terms == 0 then
    return {}
  end

  local cmd = { "rg", "--no-config", "--no-messages", "--no-heading", "--with-filename", "--line-number" }
  for _, term in ipairs(terms) do
    cmd[#cmd + 1] = "-e"
    cmd[#cmd + 1] = import_pattern(term)
  end
  cmd[#cmd + 1] = "--glob"
  cmd[#cmd + 1] = lang == "lua" and "*.lua" or "*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte}"
  cmd[#cmd + 1] = "."

  local stdout = (opts.run or M.run)(cmd, root)
  if not stdout then
    return {}
  end

  local max = opts.max_lines or 5000
  local out, seen = {}, {}
  for line in stdout:gmatch("[^\r\n]+") do
    local path, lnum, text = line:match("^(.-):(%d+):(.*)$")
    if path then
      path = path:gsub("^%./", "")
      if path:sub(1, 1) ~= "/" then
        path = root .. "/" .. path
      end
      path = normalize(path)
      local key = path .. "\0" .. lnum
      if not seen[key] then
        seen[key] = true
        out[#out + 1] = { file = path, line = tonumber(lnum), text = text }
        if #out >= max then
          break
        end
      end
    end
  end
  return out
end

--- Use ripgrep to find candidate files that may import `file`.
---@param terms string[]
---@param root string
---@param lang "js"|"lua"|string
---@param opts? { run?: fun(cmd: string[], cwd: string): string|nil, max_files?: number }
---@return string[]
function M.scan(terms, root, lang, opts)
  opts = opts or {}
  if #terms == 0 then
    return {}
  end

  local cmd = { "rg", "--no-config", "--no-messages", "-l", "-F" }
  for _, term in ipairs(terms) do
    cmd[#cmd + 1] = "-e"
    cmd[#cmd + 1] = term
  end
  cmd[#cmd + 1] = "--glob"
  cmd[#cmd + 1] = lang == "lua" and "*.lua" or "*.{ts,tsx,mts,cts,js,jsx,mjs,cjs,vue,svelte}"
  cmd[#cmd + 1] = "."

  local stdout = (opts.run or M.run)(cmd, root)
  if not stdout then
    return {}
  end

  local files = {}
  for line in stdout:gmatch("[^\r\n]+") do
    line = line:gsub("^%./", "")
    if line ~= "" then
      files[#files + 1] = normalize(line:sub(1, 1) == "/" and line or (root .. "/" .. line))
    end
  end

  table.sort(files)
  local max = opts.max_files or 2000
  if #files > max then
    return vim.list_slice(files, 1, max)
  end
  return files
end

--- Find files that import `file`.
---@param file string
---@param opts? { root?: string, run?: fun(cmd: string[], cwd: string): string|nil, max_lines?: number, scan?: fun(terms: string[], root: string, lang: string, opts: table): string[] }
---@return ImportGraph.Entry[]
function M.dependents(file, opts)
  opts = opts or {}
  file = normalize(file)

  local lang = M.lang(file)
  if not lang then
    return {}
  end

  local root = opts.root or M.root(file)
  local terms = M.terms(file, root, lang)
  if #terms == 0 then
    return {}
  end

  local cache_key = not opts.scan and (root .. "\0" .. file) or nil
  local cached = cache_key and dependents_cache[cache_key]
  if cached and (uv.hrtime() - cached.time) / 1e9 < (opts.ttl or DEPENDENTS_TTL) then
    return cached.value
  end

  -- Allow tests and other callers to provide candidates as file paths.
  local candidates
  if opts.scan then
    candidates = {}
    for _, candidate in ipairs(opts.scan(terms, root, lang, opts) or {}) do
      candidates[#candidates + 1] = { file = candidate }
    end
  else
    candidates = M.scan_lines(terms, root, lang, opts)
  end

  local parsed_cache = {}
  local out, seen = {}, {}

  for _, candidate in ipairs(candidates) do
    local path = normalize(candidate.file)
    if path ~= file and not seen[path] then
      local imports
      if candidate.text then
        -- The scan already gave us the matching import line.
        imports = M.parse(candidate.text, lang)
      else
        imports = parsed_cache[path]
        if not imports then
          local text = M.read(path)
          imports = text and M.parse(text, lang) or {}
          parsed_cache[path] = imports
        end
      end

      for _, import in ipairs(imports) do
        local resolved = M.resolve(import.spec, path, { root = root, lang = lang })
        if resolved.file == file then
          seen[path] = true
          out[#out + 1] = {
            file = path,
            spec = import.spec,
            line = candidate.line or import.line,
            kind = import.kind,
          }
          break
        end
      end
    end
  end

  table.sort(out, function(a, b)
    return (a.file or "") < (b.file or "")
  end)

  if cache_key then
    dependents_cache[cache_key] = { time = uv.hrtime(), value = out }
  end
  return out
end

return M
