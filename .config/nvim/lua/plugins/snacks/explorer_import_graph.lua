-- Floating import graph of the current buffer.
--
-- Shows the files the active buffer imports and the files that import it.
-- Nodes can be expanded lazily to walk the graph further in the same
-- direction (transitive imports / transitive importers).
--
-- Importers are resolved with LSP symbol references (fast). If no LSP client
-- can answer, a ripgrep scan is used as a fallback; `R` forces that full scan.
--
-- Typing in the input searches the files that belong to this graph: the full
-- transitive import closure plus every node seen so far, but not unrelated
-- project files. The closure is built in the background when the picker opens.
--
-- This file is self-contained: it only registers a new Snacks picker source,
-- so no other part of the config needs to change.

local features = require("config.snacks.features")
local keybindings = require("keybindings").snacks

if not features.explorer_import_graph then
  return {}
end

local Graph = require("libs.import_graph")
local keybinding = keybindings.explorer.importGraph

-- picker -> state, kept alive only while the picker exists
local states = setmetatable({}, { __mode = "k" })

---@class ImportGraph.PickerState
---@field root string
---@field project string
---@field root_text? string
---@field clients? vim.lsp.Client[]
---@field buf? number
---@field known table<string, boolean>
---@field closure? string[]
---@field closure_seen? table<string, boolean>
---@field closure_done? boolean
---@field closure_building? boolean
---@field refind_gen? number
---@field force_rg? boolean
---@field cache table<string, ImportGraph.Entry[]>
---@field expanded table<string, boolean>
---@field show_external boolean

--- Path relative to the project root, falling back to the absolute path.
---@param project string
---@param file string
---@return string
local function relpath(project, file)
  return vim.fs.relpath(project, file) or file
end

--- Latest buffer contents for a file, so unsaved edits are respected.
--- Returns nil in a fast event context where the API cannot be used; the
--- caller falls back to the file on disk.
---@param file string
---@return string|nil
local function buffer_text(file)
  if vim.in_fast_event() then
    return nil
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == file then
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    end
  end
end

--- Run a command without blocking the picker's async context when possible.
---@param ctx snacks.picker.finder.ctx
---@param cmd string[]
---@param cwd string
---@return string|nil
local function run(ctx, cmd, cwd)
  local async = ctx and ctx.async
  if not async then
    return Graph.run(cmd, cwd)
  end

  local stdout, code
  vim.system(cmd, { text = true, cwd = cwd }, function(out)
    stdout, code = out.stdout, out.code
    async:resume()
  end)
  async:suspend()

  if code ~= 0 and code ~= 1 then
    return nil
  end
  return stdout
end

--- Pick the most specific LSP client that can answer for `file`.
---@param state ImportGraph.PickerState
---@param file string
---@return vim.lsp.Client|nil
local function lsp_client(state, file)
  local best, best_len
  for _, client in ipairs(state.clients or {}) do
    if
      client.initialized
      and client.server_capabilities
      and client.server_capabilities.referencesProvider
    then
      local roots = {}
      if client.config and client.config.root_dir then
        roots[#roots + 1] = client.config.root_dir
      end
      for _, folder in ipairs(client.workspace_folders or {}) do
        roots[#roots + 1] = folder.name
      end
      if #roots == 0 then
        return client
      end
      for _, root in ipairs(roots) do
        if vim.startswith(file, root) and (not best_len or #root > best_len) then
          best, best_len = client, #root
        end
      end
    end
  end
  return best
end

--- Run a single LSP request in the picker's async context.
---@param ctx snacks.picker.finder.ctx
---@param client vim.lsp.Client
---@param bufnr number
---@param method string
---@param params table
---@param timeout number
---@return any|nil
local function lsp_request(ctx, client, bufnr, method, params, timeout)
  local async = ctx.async
  local result, finished = nil, false

  local function finish()
    if finished then
      return
    end
    finished = true
    async:resume()
  end

  -- client:request uses buffer APIs internally, so submit it on the main loop
  -- (the finder runs in a fast event context).
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      finish()
      return
    end
    client:request(method, params, function(err, res)
      if not err then
        result = res
      end
      finish()
    end, bufnr)
  end)

  vim.defer_fn(finish, timeout)
  async:suspend()
  return result
end

--- Run `textDocument/references` for several positions concurrently.
---@param ctx snacks.picker.finder.ctx
---@param client vim.lsp.Client
---@param bufnr number
---@param uri string
---@param positions table[]
---@param timeout number
---@return table[]|nil responses, nil when every request failed
local function lsp_references(ctx, client, bufnr, uri, positions, timeout)
  if #positions == 0 then
    return {}
  end

  local async = ctx.async
  local responses, remaining, errors = {}, #positions, 0
  local finished = false

  local function finish()
    if finished then
      return
    end
    finished = true
    async:resume()
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      errors = #positions
      finish()
      return
    end
    for _, position in ipairs(positions) do
      client:request("textDocument/references", {
        textDocument = { uri = uri },
        position = position,
        context = { includeDeclaration = false },
      }, function(err, result)
        if finished then
          return
        end
        if err then
          errors = errors + 1
        else
          responses[#responses + 1] = result
        end
        remaining = remaining - 1
        if remaining == 0 then
          finish()
        end
      end, bufnr)
    end
  end)

  vim.defer_fn(finish, timeout)
  async:suspend()
  if errors == #positions then
    return nil
  end
  return responses
end

--- Line numbers occupied by imports / re-exports, so their symbols do not
--- pollute the reference query.
---@param text string
---@return table<number, boolean>
local function import_lines(text)
  local ret = {}
  local importing = false
  local lnum = 0
  for line in (text .. "\n"):gmatch("(.-)\n") do
    lnum = lnum + 1
    if line:match("^%s*import%s") then
      importing = true
    end
    if importing then
      ret[lnum] = true
    end
    if importing and (line:match("from%s*['\"]") or line:match("^%s*import%s*['\"]")) then
      importing = false
    end
    if line:match("^%s*export%s.-from%s*['\"]") or line:match("^%s*export%s*%*%s*from") then
      ret[lnum] = true
    end
  end
  return ret
end

--- Wait briefly for an attached LSP client to finish initializing.
---@param ctx snacks.picker.finder.ctx
---@param state ImportGraph.PickerState
---@param file string
---@param timeout number
---@return vim.lsp.Client|nil
local function wait_client(ctx, state, file, timeout)
  local client = lsp_client(state, file)
  if client or not state.clients or #state.clients == 0 then
    return client
  end

  local async = ctx.async
  local uv = vim.uv or vim.loop
  local deadline = uv.hrtime() + timeout * 1e6
  while uv.hrtime() < deadline do
    vim.defer_fn(function()
      async:resume()
    end, 50)
    async:suspend()
    client = lsp_client(state, file)
    if client then
      return client
    end
  end
end

--- Find importers with LSP symbol references (fast). Returns nil when LSP
--- cannot answer, so the caller can fall back to a ripgrep scan.
---@param ctx snacks.picker.finder.ctx
---@param state ImportGraph.PickerState
---@param file string
---@return ImportGraph.Entry[]|nil
local function lsp_importers(ctx, state, file)
  if Graph.lang(file) ~= "js" then
    return nil
  end

  local client = wait_client(ctx, state, file, 1000)
  if not client or not state.buf then
    return nil
  end

  local uri = vim.uri_from_fname(file)
  local symbols = lsp_request(ctx, client, state.buf, "textDocument/documentSymbol", {
    textDocument = { uri = uri },
  }, 8000)
  if not symbols or #symbols == 0 then
    return nil
  end

  local text = Graph.read(file)
  if not text then
    return nil
  end

  local skip = import_lines(text)
  local positions = {}
  for _, symbol in ipairs(symbols) do
    local range = symbol.selectionRange or symbol.range
    if range and not skip[range.start.line + 1] then
      positions[#positions + 1] = range.start
    end
  end
  if #positions == 0 then
    return nil
  end

  local responses = lsp_references(ctx, client, state.buf, uri, positions, 5000)
  if not responses then
    return nil
  end

  local files, seen = {}, {}
  for _, response in ipairs(responses) do
    for _, ref in ipairs(response or {}) do
      local path = vim.uri_to_fname(ref.uri)
      if path ~= file and not path:find("/node_modules/", 1, true) and not seen[path] then
        seen[path] = true
        files[#files + 1] = path
      end
    end
  end

  -- Keep only files that import the target directly. LSP also reports usage
  -- through re-exporting barrels, which are not direct imports.
  local out, parsed = {}, {}
  for _, path in ipairs(files) do
    local imports = parsed[path]
    if not imports then
      local content = Graph.read(path)
      imports = content and Graph.parse(content, "js") or {}
      parsed[path] = imports
    end
    for _, import in ipairs(imports) do
      local resolved = Graph.resolve(import.spec, path, { root = state.project })
      if resolved.file == file then
        out[#out + 1] = { file = path, spec = import.spec, line = import.line }
        break
      end
    end
  end

  table.sort(out, function(a, b)
    return (a.file or "") < (b.file or "")
  end)
  return out
end

---@param ctx snacks.picker.finder.ctx
---@param state ImportGraph.PickerState
---@param direction "out"|"in"
---@param file string
---@return ImportGraph.Entry[]
local function entries(ctx, state, direction, file)
  local key = direction .. "\0" .. file
  local cached = state.cache[key]
  if cached then
    return cached
  end

  state.known[file] = true

  local entries_for_file
  if direction == "out" then
    entries_for_file = Graph.dependencies(file, {
      root = state.project,
      text = file == state.root and state.root_text or nil,
    })
  else
    -- LSP symbol references are orders of magnitude faster than a repository
    -- scan. Fall back to ripgrep when no client can answer, or when the user
    -- explicitly asks for a full rescan (`R`).
    if not state.force_rg then
      entries_for_file = lsp_importers(ctx, state, file)
    end
    if not entries_for_file then
      entries_for_file = Graph.dependents(file, {
        root = state.project,
        run = function(cmd, cwd)
          return run(ctx, cmd, cwd)
        end,
      })
    end
  end

  for _, entry in ipairs(entries_for_file) do
    if entry.file then
      state.known[entry.file] = true
    end
  end

  state.cache[key] = entries_for_file
  return entries_for_file
end

---@param picker snacks.Picker
---@param state ImportGraph.PickerState
---@param ctx snacks.picker.finder.ctx
---@param cb fun(item: table)
local function emit(picker, state, ctx, cb)
  ---@param item table
  ---@param sort string hierarchical sort key
  local function add(item, sort)
    item.sort = sort
    item.text = item.text or relpath(state.project, item.file or "")
    if item.file then
      state.known[item.file] = true
    end
    cb(item)
  end

  local root = {
    file = state.root,
    root = true,
    id = "root",
    depth = 0,
    filename_hl = "SnacksPickerImportGraphRoot",
    text = relpath(state.project, state.root),
  }
  add(root, "")

  --- Group cached entries for a direction without computing them.
  ---@param direction "out"|"in"
  ---@param file string
  ---@return table[]|nil
  local function cached(direction, file)
    local list = state.cache[direction .. "\0" .. file]
    if not list then
      return nil
    end
    local ret = {}
    for _, entry in ipairs(list) do
      ret[#ret + 1] = { direction = direction, entry = entry }
    end
    return ret
  end

  --- Compute entries for a direction (may suspend on a ripgrep scan).
  ---@param direction "out"|"in"
  ---@param file string
  ---@return table[]
  local function collect(direction, file)
    local ret = {}
    for _, entry in ipairs(entries(ctx, state, direction, file)) do
      ret[#ret + 1] = { direction = direction, entry = entry }
    end
    return ret
  end

  ---@param file string
  ---@param parent table
  ---@return boolean
  local function is_ancestor(file, parent)
    local node = parent
    while node do
      if node.file == file then
        return true
      end
      node = node.parent
    end
    return false
  end

  -- Expansions whose importers still need a ripgrep scan. They are processed
  -- only after the whole known tree is emitted, so expanding one node never
  -- hides its siblings while the scan runs.
  local deferred = {}

  ---@param list table[]
  ---@param parent table
  ---@param depth number
  ---@param final boolean whether this is the last sibling group of `parent`
  ---@param prefix string sort prefix of this sibling group
  ---@return boolean emitted, table|nil last_node
  local function children(list, parent, depth, final, prefix)
    local visible = {}
    for _, value in ipairs(list) do
      if not value.entry.external or state.show_external then
        visible[#visible + 1] = value
      end
    end

    local last_node
    for index, value in ipairs(visible) do
      local entry, direction = value.entry, value.direction
      local key = entry.external and ("external\0" .. entry.external) or (direction .. "\0" .. entry.file)
      local cycle = entry.file ~= nil and is_ancestor(entry.file, parent)
      -- Unique per tree instance: the same file can appear in several
      -- branches, and expanding one instance must not expand the others.
      local id = parent.id .. ">" .. key
      local sort = prefix .. "/" .. ("%06d"):format(index)

      local node = {
        file = entry.file,
        external = entry.external,
        spec = entry.spec,
        line = entry.line,
        kind = entry.kind,
        direction = direction,
        parent = parent,
        id = id,
        depth = depth,
        last = final and index == #visible,
        cycle = cycle,
        collapsed = not state.expanded[id],
      }
      add(node, sort)

      if state.expanded[id] and entry.file and not cycle then
        if direction == "in" then
          local cached_list = cached(direction, entry.file)
          if cached_list then
            children(cached_list, node, depth + 1, true, sort)
          else
            deferred[#deferred + 1] = {
              node = node,
              file = entry.file,
              depth = depth,
              sort = sort,
            }
          end
        else
          -- Import scanning is only needed for "in"; "out" is local and fast.
          children(collect(direction, entry.file), node, depth + 1, true, sort)
        end
      end
      last_node = node
    end

    return #visible > 0, last_node
  end

  -- Emit the fast part (root, imports and cached importers) before any scan.
  local out_emitted, out_last = children(collect("out", state.root), root, 1, false, "0")

  local importers = cached("in", state.root)
  if importers then
    local emitted = children(importers, root, 1, true, "1")
    if out_emitted and not emitted and out_last then
      -- No importers: close the tree instead of leaving a dangling branch.
      out_last.last = true
      picker.list.dirty = true
    end
  else
    deferred[#deferred + 1] = { node = root, file = state.root, depth = 0, sort = "", root_in = true }
  end

  -- Now resolve the remaining importer lists one by one. All already known
  -- siblings are visible by this point, and stay visible while a scan runs.
  local index = 1
  while index <= #deferred do
    local task = deferred[index]
    index = index + 1

    local list = collect("in", task.file)
    if task.root_in then
      local emitted = children(list, root, 1, true, "1")
      if out_emitted and not emitted and out_last then
        out_last.last = true
        picker.list.dirty = true
      end
    else
      children(list, task.node, task.depth + 1, true, task.sort)
    end
  end

  state.force_rg = nil
end

--- Build the transitive import closure in small main-loop chunks, so the
--- search covers nested dependencies that were never expanded. This is
--- parse-only (no LSP), so it does not depend on which project is loaded.
---@param picker snacks.Picker
---@param state ImportGraph.PickerState
local function start_closure(picker, state)
  if state.closure_done or state.closure_building then
    return
  end
  state.closure_building = true
  state.closure = { state.root }
  state.closure_seen = { [state.root] = true }

  local uv = vim.uv or vim.loop
  local queue = { state.root }
  local index = 1

  local function step()
    if picker.closed then
      state.closure_building = false
      return
    end

    local deadline = uv.hrtime() + 4e6 -- 4 ms per tick
    while index <= #queue and uv.hrtime() < deadline do
      local file = queue[index]
      index = index + 1

      local deps = Graph.dependencies(file, {
        root = state.project,
        text = file == state.root and state.root_text or nil,
      })
      for _, entry in ipairs(deps) do
        local path = entry.file
        if path and not state.closure_seen[path] then
          state.closure_seen[path] = true
          state.closure[#state.closure + 1] = path
          queue[#queue + 1] = path
        end
      end
    end

    if index <= #queue then
      vim.defer_fn(step, 5)
    else
      state.closure_building = false
      state.closure_done = true
    end
  end

  step()
end

---@param opts snacks.picker.Config
---@param ctx snacks.picker.finder.ctx
---@type snacks.picker.finder
local function find(opts, ctx)
  local picker = ctx.picker
  local state = states[picker]

  if not state then
    local root = opts.root_file
    if not root or root == "" then
      root = vim.api.nvim_buf_get_name(0)
    end
    root = vim.fs.normalize(root)

    local bufnr = opts.buf
    if not bufnr then
      for _, client in ipairs(opts.clients or {}) do
        bufnr = next(client.attached_buffers or {})
        if bufnr then
          break
        end
      end
    end

    state = {
      root = root,
      project = opts.project_root or Graph.root(root),
      clients = opts.clients,
      buf = bufnr,
      cache = {},
      expanded = {},
      known = { [root] = true },
      show_external = opts.show_external or false,
    }
    states[picker] = state
  end

  -- Capture unsaved buffer contents here, on the main loop; the finder body
  -- runs in a fast event context where the buffer API is unavailable.
  if not vim.in_fast_event() then
    state.root_text = buffer_text(state.root)
    -- LSP clients can attach after the picker was created; refresh the list.
    if (not state.clients or #state.clients == 0) and state.buf then
      state.clients = vim.lsp.get_clients({ bufnr = state.buf })
    end
  end

  -- Preload the transitive import closure in the background, so searching
  -- finds nested dependencies without expanding the tree first.
  if not state.closure_done and not state.closure_building and not vim.in_fast_event() then
    vim.defer_fn(function()
      start_closure(picker, state)
    end, 150)
  end

  local searching = not ctx.filter:is_empty()
  -- Keep directory parents visible while filtering the search tree.
  ctx.picker.matcher.opts.keep_parents = searching

  ---@param cb fun(item: table)
  return function(cb)
    if not searching then
      emit(picker, state, ctx, cb)
      state.force_rg = nil
      return
    end

    -- Wait for the background closure if it is still being built, so nested
    -- dependencies are searchable even when the tree was never expanded.
    if not state.closure_done then
      start_closure(picker, state)
      local async = ctx.async
      local uv = vim.uv or vim.loop
      local deadline = uv.hrtime() + 15e9
      while not state.closure_done and uv.hrtime() < deadline and not picker.closed do
        vim.defer_fn(function()
          async:resume()
        end, 25)
        async:suspend()
      end
    end

    -- Search the graph: transitive imports plus every node seen so far
    -- (including file importers and children of collapsed branches).
    local files, seen = {}, {}
    local function add(path)
      if path and not seen[path] then
        seen[path] = true
        files[#files + 1] = path
      end
    end
    for _, path in ipairs(state.closure or {}) do
      add(path)
    end
    for path in pairs(state.known) do
      add(path)
    end
    table.sort(files)

    -- Group the matches into a directory tree, like the Snacks explorer.
    local dirs, groups, items = {}, {}, {}

    ---@param rel string
    ---@return table|nil item, string prefix
    local function ensure_dir(rel)
      if rel == "" or rel == "." then
        return nil, ""
      end
      local existing = dirs[rel]
      if existing then
        return existing, existing.sort
      end

      local parent_rel = vim.fs.dirname(rel)
      if parent_rel == "." then
        parent_rel = ""
      end
      local parent, prefix = ensure_dir(parent_rel)
      local item = {
        file = state.project .. "/" .. rel,
        dir = true,
        open = true,
        search = true,
        text = rel,
        sort = prefix .. "!" .. vim.fs.basename(rel) .. " ",
        parent = parent,
      }
      dirs[rel] = item
      items[#items + 1] = item

      local group = groups[parent_rel]
      if not group then
        group = {}
        groups[parent_rel] = group
      end
      group[#group + 1] = item
      return item, item.sort
    end

    for _, file in ipairs(files) do
      local rel = relpath(state.project, file)
      if rel:sub(1, 1) == "/" then
        -- Outside the project root: keep it as a flat entry.
        items[#items + 1] = { file = file, search = true, text = rel, sort = "~" .. rel }
      else
        local dir_rel = vim.fs.dirname(rel)
        if dir_rel == "." then
          dir_rel = ""
        end
        local parent, prefix = ensure_dir(dir_rel)
        local item = {
          file = file,
          search = true,
          text = rel,
          sort = prefix .. "#" .. vim.fs.basename(rel) .. " ",
          parent = parent,
        }
        items[#items + 1] = item

        local group = groups[dir_rel]
        if not group then
          group = {}
          groups[dir_rel] = group
        end
        group[#group + 1] = item
      end
    end

    -- Tree glyphs need a `last` flag per sibling group.
    for _, group in pairs(groups) do
      table.sort(group, function(a, b)
        return a.sort < b.sort
      end)
      for index, item in ipairs(group) do
        item.last = index == #group
      end
    end

    for _, item in ipairs(items) do
      cb(item)
    end
    state.force_rg = nil
  end
end

--- Refetch the graph, keeping the cursor on the same tree instance.
--- Snacks clears the list (and its cursor) on every find, so the node is
--- restored by its unique tree id once the new items are in place.
---@param picker snacks.Picker
---@param opts? { reveal?: boolean } `reveal = false` focuses the first row
local function refind(picker, opts)
  opts = opts or {}
  local reveal = opts.reveal ~= false
  local current = picker:current()
  local id = reveal and current and current.id or nil

  local state = states[picker]
  local gen = ((state and state.refind_gen) or 0) + 1
  if state then
    state.refind_gen = gen
  end

  if reveal then
    -- List:clear() resets the cursor but leaves a pending target intact.
    picker.list:set_target()
  end

  picker:find({
    on_done = function()
      if picker.closed or (states[picker] and states[picker].refind_gen ~= gen) then
        return
      end

      local target = 1
      if id then
        for item, idx in picker:iter() do
          if item.id == id then
            target = idx
            break
          end
        end
      end

      if picker.list.paused then
        picker.list:view(target, nil, false)
        picker.list:unpause()
      else
        picker.list:view(target)
      end
    end,
  })

  -- find() pauses list updates. Release the pause once the finder emitted
  -- enough items for the pending target, so the first render already has the
  -- cursor on the right row (the finder may suspend during importer scans).
  local function release(tries)
    if picker.closed or not picker.list.paused then
      return
    end
    if states[picker] and states[picker].refind_gen ~= gen then
      return -- a newer find owns the pause now
    end
    local target = picker.list.target and picker.list.target.cursor or 1
    if picker.list:count() >= target or tries <= 0 then
      picker.list:unpause()
      return
    end
    vim.defer_fn(function()
      release(tries - 1)
    end, 10)
  end
  release(50)
end

---@param picker snacks.Picker
---@param item table|nil
---@param expanded boolean
local function set_expanded(picker, item, expanded)
  local state = states[picker]
  if not state or not item or not item.id or item.external or item.cycle then
    return
  end

  state.expanded[item.id] = expanded or nil
  refind(picker)
end

local actions = {
  import_graph_expand = function(picker, item)
    set_expanded(picker, item, true)
  end,

  import_graph_collapse = function(picker, item)
    local state = states[picker]
    if not state then
      return
    end
    if item and item.root then
      state.expanded = {}
    elseif item and item.id then
      state.expanded[item.id] = nil
    end
    refind(picker)
  end,

  import_graph_toggle = function(picker, item)
    if not item or not item.id then
      return
    end
    set_expanded(picker, item, item.collapsed)
  end,

  import_graph_recenter = function(picker, item)
    local state = states[picker]
    if not state or not item or not item.file or item.external or item.dir then
      return
    end
    state.root = item.file
    state.project = Graph.root(item.file)
    state.cache = {}
    state.expanded = {}
    state.known = { [item.file] = true }
    state.closure = nil
    state.closure_seen = nil
    state.closure_done = nil
    state.closure_building = nil
    -- Drop an active file search so the new graph is visible right away.
    if not picker.input.filter:is_empty() then
      picker.input:set("", "")
    end
    refind(picker, { reveal = false })
  end,

  import_graph_refresh = function(picker)
    local state = states[picker]
    if state then
      state.cache = {}
      state.force_rg = true -- full rescan, including other TS projects
      state.closure = nil
      state.closure_seen = nil
      state.closure_done = nil
      state.closure_building = nil
    end
    Graph.clear_cache()
    refind(picker)
  end,

  import_graph_toggle_external = function(picker)
    local state = states[picker]
    if state then
      state.show_external = not state.show_external
    end
    refind(picker)
  end,

  confirm = function(picker, item, action)
    if item and item.dir then
      return -- directory rows only carry the tree structure
    end
    if item and item.external then
      vim.fn.setreg(vim.v.register or "+", item.external, "l")
      require("snacks").notify.info(("Copied `%s`"):format(item.external))
      return
    end
    require("snacks").picker.actions.jump(picker, item, action)
  end,
}

---@param item table
---@param picker snacks.Picker
---@return snacks.picker.Highlight[]
local function format(item, picker)
  local Format = require("snacks.picker.format")
  local ret = {}

  if item.search then
    -- Search results keep a directory tree, like the Snacks file explorer.
    if item.parent then
      vim.list_extend(ret, Format.tree(item, picker))
    end
    vim.list_extend(ret, Format.filename(item, picker))
    return ret
  end

  if item.parent then
    vim.list_extend(ret, Format.tree(item, picker))
  end

  if item.root then
    ret[#ret + 1] = { "󰒍 ", "SnacksPickerImportGraphRoot", virtual = true }
  elseif item.external then
    ret[#ret + 1] = { "◇ ", "SnacksPickerDimmed", virtual = true }
  elseif item.cycle then
    ret[#ret + 1] = { "↺ ", "SnacksPickerDimmed", virtual = true }
  else
    ret[#ret + 1] = { item.collapsed and "▸ " or "▾ ", "SnacksPickerDimmed", virtual = true }
    ret[#ret + 1] = {
      item.direction == "in" and "← " or "→ ",
      item.direction == "in" and "SnacksPickerImportGraphIn" or "SnacksPickerImportGraphOut",
      virtual = true,
    }
  end

  if item.external then
    ret[#ret + 1] = { item.external, "SnacksPickerDimmed" }
  else
    vim.list_extend(ret, Format.filename(item, picker))
  end

  if item.line then
    ret[#ret + 1] = { ":" .. item.line, "SnacksPickerDimmed", virtual = true }
  end

  return ret
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    require("snacks.util").set_hl({
      ImportGraphRoot = "Title",
      ImportGraphOut = "DiagnosticInfo",
      ImportGraphIn = "DiagnosticWarn",
    }, { prefix = "SnacksPicker", default = true })

    opts.picker = opts.picker or {}
    opts.picker.sources = opts.picker.sources or {}
    opts.picker.sources.import_graph = {
      finder = find,
      format = format,
      title = "Import graph",
      focus = "list",
      sort = { fields = { "sort" } },
      matcher = { sort_empty = false, fuzzy = false },
      filter = {
        -- Switch between the tree and the flat file search when the input
        -- becomes empty / non-empty (the finder is otherwise not re-run).
        transform = function(picker, filter)
          local searching = not filter:is_empty()
          if picker._import_graph_searching ~= searching then
            picker._import_graph_searching = searching
            filter.meta.searching = searching
            return true
          end
        end,
      },
      actions = actions,
      show_external = false,
      layout = {
        preview = false,
        layout = {
          backdrop = false,
          width = 0.55,
          min_width = 70,
          height = 0.7,
          min_height = 10,
          border = "rounded",
          box = "vertical",
          title = "{title} {flags}",
          title_pos = "center",
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
        },
      },
      win = {
        list = {
          keys = {
            ["l"] = { "import_graph_expand", mode = "n", desc = "Expand" },
            ["h"] = { "import_graph_collapse", mode = "n", desc = "Collapse" },
            ["<Right>"] = { "import_graph_expand", mode = "n", desc = "Expand" },
            ["<Left>"] = { "import_graph_collapse", mode = "n", desc = "Collapse" },
            ["r"] = { "import_graph_recenter", mode = "n", desc = "Re-center on this file" },
            ["R"] = { "import_graph_refresh", mode = "n", desc = "Refresh" },
            ["e"] = { "import_graph_toggle_external", mode = "n", desc = "Toggle external imports" },
          },
        },
      },
    }
  end,
  keys = {
    {
      keybinding.shortcut,
      function()
        local buf = vim.api.nvim_get_current_buf()
        local file = vim.api.nvim_buf_get_name(buf)

        if file == "" then
          require("snacks").notify.warn("Import graph: the current buffer has no file")
          return
        end

        file = vim.fs.normalize(file)
        if not Graph.lang(file) then
          require("snacks").notify.warn(
            ("Import graph: unsupported filetype `%s`"):format(vim.bo[buf].filetype)
          )
          return
        end

        local root = Graph.root(file)
        -- Keep all clients; capabilities become available after initialize.
        local clients = vim.lsp.get_clients({ bufnr = buf })

        require("snacks").picker.pick("import_graph", {
          root_file = file,
          project_root = root,
          cwd = root,
          buf = buf,
          clients = clients,
        })
      end,
      mode = keybinding.mode,
      desc = keybinding.desc,
    },
  },
}
