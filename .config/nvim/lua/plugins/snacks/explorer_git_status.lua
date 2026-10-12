local features = require("config.snacks.features")
local keybindings = require("keybindings").snacks

if not features.explorer_git_status then
  return {}
end

local function is_git_item(item, git_nodes)
  return vim.iter(git_nodes):any(function(node)
    if node.dir_status then
      return vim.fs.relpath(node.path, item.file) ~= nil
    end
    return vim.fs.relpath(item.file, node.path) ~= nil
  end)
end

return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    opts.picker = opts.picker or {}
    opts.picker.sources = opts.picker.sources or {}
    local explorer = opts.picker.sources.explorer or {}
    explorer.finder = function(finder_opts, ctx)
      local tree = require("snacks.explorer.tree")
      local git_nodes = {}
      tree:walk(tree:find(ctx.picker:cwd()), function(node)
        if node.status then
          git_nodes[#git_nodes + 1] = node
        end
      end)
      ctx.picker.git_nodes = git_nodes
      return require("snacks.picker.source.explorer").explorer(finder_opts, ctx)
    end
    explorer.transform = function(item, ctx)
      if ctx.picker.opts.only_git then
        return is_git_item(item, ctx.picker.git_nodes)
      end
    end
    explorer.only_git = false
    explorer.toggles = vim.tbl_deep_extend("force", explorer.toggles or {}, {
      only_git = keybindings.explorer.toggleGitStatus.shortcut,
    })
    explorer.win = explorer.win or {}
    explorer.win.list = explorer.win.list or {}
    explorer.win.list.keys = vim.tbl_deep_extend("force", explorer.win.list.keys or {}, {
      [keybindings.explorer.toggleGitStatus.shortcut] = {
        "toggle_only_git",
        desc = keybindings.explorer.toggleGitStatus.desc,
        mode = keybindings.explorer.toggleGitStatus.mode,
      },
    })
    opts.picker.sources.explorer = explorer
  end,
}
