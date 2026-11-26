-- Tests for libs/import_graph/init.lua using mini.test
-- Run: nvim --headless -u NONE -l scripts/minitest.lua

package.path = vim.fn.stdpath("config") .. "/lua/?.lua;" .. package.path

local MiniTest = require("mini.test")
local T = MiniTest.new_set()
local Graph = require("libs.import_graph")

local eq = MiniTest.expect.equality

---@param root string
---@param path string
---@param content string
---@return string
local function write(root, path, content)
  local full = vim.fs.joinpath(root, path)
  vim.fn.mkdir(vim.fs.dirname(full), "p")
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), full)
  return full
end

---@return string
local function project()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  return root
end

local function specs(imports)
  return vim.tbl_map(function(import)
    return import.spec
  end, imports)
end

local function files(entries)
  local ret = {}
  for _, entry in ipairs(entries) do
    ret[#ret + 1] = entry.file or entry.external
  end
  return ret
end

T["parses"] = MiniTest.new_set()

T["parses"]["js imports"] = function()
  local text = table.concat({
    'import a from "./a"',
    "import { b } from '../b'",
    'import "./side"',
    'export * from "./c"',
    'const d = require("./d")',
    'const e = import("./e")',
    '// import f from "./f"',
    'const url = "https://example.com/f"',
  }, "\n")

  eq(specs(Graph.parse(text, "js")), { "./a", "../b", "./side", "./c", "./d", "./e" })
end

T["parses"]["lua require"] = function()
  local text = table.concat({
    'local a = require("libs.a")',
    "local b = require 'libs.b'",
    '-- local c = require("libs.c")',
  }, "\n")

  eq(specs(Graph.parse(text, "lua")), { "libs.a", "libs.b" })
end

T["parses"]["records line numbers"] = function()
  local imports = Graph.parse('import a from "./a"\n\nimport b from "./b"', "js")
  eq(vim.tbl_map(function(import)
    return import.line
  end, imports), { 1, 3 })
end

T["resolves"] = MiniTest.new_set()

T["resolves"]["relative imports with extensions and index files"] = function()
  local root = project()
  write(root, "package.json", "{}")
  local a = write(root, "src/a.ts", 'import "./b"\nimport "./dir"\nimport "./c.js"')
  write(root, "src/b.ts", "export {}")
  write(root, "src/dir/index.ts", "export {}")
  write(root, "src/c.js", "export {}")

  eq(files(Graph.dependencies(a)), {
    root .. "/src/b.ts",
    root .. "/src/dir/index.ts",
    root .. "/src/c.js",
  })
end

T["resolves"]["tsconfig paths"] = function()
  local root = project()
  write(root, "package.json", "{}")
  write(
    root,
    "tsconfig.json",
    [[{
      // aliases
      "compilerOptions": {
        "baseUrl": ".",
        "paths": {
          "@/*": ["src/*"],
        },
      },
    }]]
  )
  local a = write(root, "src/a.ts", 'import b from "@/b"')
  write(root, "src/b.ts", "export {}")

  eq(files(Graph.dependencies(a)), { root .. "/src/b.ts" })
end

T["resolves"]["workspace packages via node_modules and exports"] = function()
  local root = project()
  write(root, "package.json", "{}")
  write(root, "packages/ui/package.json", [[{"name":"@repo/ui","exports":{"./*":"./src/*.tsx"}}]])
  write(root, "packages/ui/src/button.tsx", "export {}")

  vim.fn.mkdir(root .. "/node_modules/@repo", "p")
  assert(vim.uv.fs_symlink(root .. "/packages/ui", root .. "/node_modules/@repo/ui", { dir = true }))

  local a = write(root, "apps/web/src/page.tsx", 'import { Button } from "@repo/ui/button"')
  local expected = vim.uv.fs_realpath(root .. "/packages/ui/src/button.tsx")

  eq(files(Graph.dependencies(a)), { expected })
end

T["resolves"]["lua modules and init files"] = function()
  local root = project()
  local a = write(root, "lua/a.lua", 'require("libs.foo")\nrequire("libs.bar")')
  write(root, "lua/libs/foo.lua", "return {}")
  write(root, "lua/libs/bar/init.lua", "return {}")

  eq(Graph.root(a), root)
  eq(files(Graph.dependencies(a)), {
    root .. "/lua/libs/foo.lua",
    root .. "/lua/libs/bar/init.lua",
  })
end

T["resolves"]["marks bare js imports as external"] = function()
  local root = project()
  write(root, "package.json", "{}")
  local a = write(root, "src/a.ts", 'import react from "react"\nimport b from "./missing"')

  eq(files(Graph.dependencies(a)), { "react" })
end

T["terms"] = MiniTest.new_set()

T["terms"]["uses the file basename as a path segment"] = function()
  local root = "/repo"
  eq(Graph.terms(root .. "/src/components/Button.tsx", root, "js"), { "/Button" })
end

T["terms"]["uses the directory name for index files"] = function()
  local root = "/repo"
  eq(Graph.terms(root .. "/src/components/Alert/index.tsx", root, "js"), { "/Alert" })
end

T["terms"]["uses the lua module name"] = function()
  local root = "/repo"
  eq(Graph.terms(root .. "/lua/libs/foo.lua", root, "lua"), { "libs.foo", "libs/foo" })
end

T["dependents"] = MiniTest.new_set()

T["dependents"]["finds the files that import the target"] = function()
  local root = project()
  write(root, "package.json", "{}")
  local target = write(root, "src/b.ts", "export {}")
  local first = write(root, "src/a.ts", 'import b from "./b"')
  local second = write(root, "src/c.ts", 'import b from "./b"')
  write(root, "src/d.ts", 'import c from "./c"')

  local seen_terms
  local result = Graph.dependents(target, {
    scan = function(terms)
      seen_terms = terms
      return { first, second, target }
    end,
  })

  eq(files(result), { first, second })
  MiniTest.expect.no_equality(#seen_terms, 0)
end

T["dependents"]["lua require"] = function()
  local root = project()
  local target = write(root, "lua/libs/foo.lua", "return {}")
  local importer = write(root, "lua/a.lua", 'require("libs.foo")')
  write(root, "lua/b.lua", 'require("libs.other")')

  local result = Graph.dependents(target, {
    scan = function()
      return { importer }
    end,
  })

  eq(files(result), { importer })
end

return T
