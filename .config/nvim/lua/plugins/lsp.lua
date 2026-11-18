local keybindings = require("keybindings")

local function content_mapper_root(bufnr)
  local root = vim.fs.root(bufnr, "tsconfig.json")
  if not root then
    return
  end

  local ok, lines = pcall(vim.fn.readfile, root .. "/tsconfig.json")
  if ok and table.concat(lines, "\n"):find("contentMappers", 1, true) then
    return root
  end
end

local function typescript_root(bufnr)
  return vim.fs.root(bufnr, {
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "bun.lockb",
    "bun.lock",
    ".git",
  }) or vim.fn.getcwd()
end

local function supports_lsp(bin, minor)
  if vim.fn.executable(bin) ~= 1 then
    return false
  end

  local out = vim.system({ bin, "--version" }, { text = true }):wait()
  local version = vim.version.parse(out.stdout or "")
  local wanted = minor or 0

  return out.code == 0 and version ~= nil and (version.major > 7 or (version.major == 7 and version.minor >= wanted))
end

local function tsc_cmd(dispatchers, config, minor)
  local root = (config or {}).root_dir or vim.fn.getcwd()
  local local_bin = root .. "/node_modules/.bin/tsc"
  local bin = supports_lsp(local_bin, minor) and local_bin or "tsc"

  if not supports_lsp(bin, minor) then
    vim.notify(("tsc: no TypeScript %s+ binary found"):format(minor and ("7." .. minor) or "7"), vim.log.levels.WARN)
    return
  end

  return vim.lsp.rpc.start({ bin, "--lsp", "--stdio" }, dispatchers)
end

return {
  {
    "neovim/nvim-lspconfig",
    init = function()
      local function fix_all_kind(bufnr)
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
          if client.name == "eslint" then
            return "source.fixAll.eslint"
          elseif client.name == "oxlint" then
            return "source.fixAll.oxlint"
          end
        end
      end

      local function update_fix_all_keymap(bufnr)
        local kind = fix_all_kind(bufnr)
        local shortcut = keybindings.lsp.eslintFixAll.shortcut

        if kind then
          vim.keymap.set("n", shortcut, function()
            vim.lsp.buf.code_action({
              apply = true,
              context = {
                diagnostics = {},
                only = { kind },
              },
            })
          end, {
            buffer = bufnr,
            desc = keybindings.lsp.eslintFixAll.desc,
          })
        else
          pcall(vim.keymap.del, "n", shortcut, { buffer = bufnr })
        end
      end

      local group = vim.api.nvim_create_augroup("user_lsp_fix_all", { clear = true })
      vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
        group = group,
        callback = function(args)
          vim.schedule(function()
            update_fix_all_keymap(args.buf)
          end)
        end,
      })

      vim.keymap.set(
        keybindings.lsp.log.mode,
        keybindings.lsp.log.shortcut,
        "<Cmd>log lsp<CR>",
        { desc = keybindings.lsp.log.desc }
      )
      vim.keymap.set(
        keybindings.lsp.log.mode,
        keybindings.lsp.info.shortcut,
        "<Cmd>checkhealth vim.lsp<CR>",
        { desc = keybindings.lsp.info.desc }
      )
      -- "Client tsc quit with exit code 1" is a known tsc false positive on
      -- clean shutdown, filtered out in the Noice route in lua/plugins/ui.lua.
      local function restart_lsp()
        if #vim.lsp.get_clients({ bufnr = 0 }) == 0 then
          vim.notify("No LSP clients attached to the current buffer", vim.log.levels.WARN)
          return
        end

        vim.cmd("lsp restart")
      end

      vim.keymap.set(
        keybindings.lsp.log.mode,
        keybindings.lsp.restart.shortcut,
        restart_lsp,
        { desc = keybindings.lsp.restart.desc }
      )

      vim.keymap.set(
        keybindings.lsp.showDiagWindow.mode,
        keybindings.lsp.showDiagWindow.shortcut,
        vim.diagnostic.open_float,
        { desc = keybindings.lsp.showDiagWindow.desc }
      )
    end,
    ---@class PluginLspOpts
    opts = {
      inlay_hints = {
        enabled = false,
      },
      diagnostics = { virtual_text = false },
      -- LSP Server Settings
      ---@type lspconfig.options
      servers = {
        ["*"] = {
          keys = {
            { "K", false },
            { keybindings.lsp.hoverInfo.shortcut, vim.lsp.buf.hover, desc = keybindings.lsp.hoverInfo.desc },
            {
              keybindings.lsp.prevRef.shortcut,
              function()
                Snacks.words.jump(-vim.v.count1)
              end,
              has = "documentHighlight",
              desc = keybindings.lsp.prevRef.desc,
            },
            {
              keybindings.lsp.nextRef.shortcut,
              function()
                Snacks.words.jump(vim.v_count1)
              end,
              has = "documentHighlight",
              desc = keybindings.lsp.nextRef.desc,
            },
          },
        },
        tsc = {
          root_dir = function(bufnr, on_dir)
            if content_mapper_root(bufnr) then
              return
            end

            on_dir(typescript_root(bufnr))
          end,
          cmd = function(dispatchers, config)
            return tsc_cmd(dispatchers, config, 0)
          end,
        },
        ["tsgo-content-mapper"] = {
          mason = false,
          filetypes = { "typescript", "typescriptreact" },
          init_options = { runExternalCode = true },
          root_dir = function(bufnr, on_dir)
            local root = content_mapper_root(bufnr)
            if root then
              on_dir(root)
            end
          end,
          cmd = function(dispatchers, config)
            return tsc_cmd(dispatchers, config, 1)
          end,
        },
        lua_ls = {
          settings = {
            Lua = {
              workspace = {
                library = {
                  vim.fn.expand("$VIMRUNTIME/lua"),
                  -- make accessible lua files from the pde/ folder
                  "~/.config/pde/",
                },
                checkThirdParty = false,
              },
            },
          },
        },
      },
    },
  },
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    opts = {
      preset = "powerline",
      options = {
        add_messages = {
          display_count = true,
        },
        multilines = {
          enabled = true,
        },
      },
    },
  },

  {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = {
      {
        "DrKJeff16/wezterm-types",
        lazy = true,
        version = false, -- Get the latest version
      },
    },
    opts = {
      library = {
        -- Other library configs...
        { path = "wezterm-types", mods = { "wezterm" } },
      },
    },
  },
}
