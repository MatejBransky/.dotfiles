-- Modes
-- n  Normal mode map. Defined using ':nmap' or ':nnoremap'.
-- i  Insert mode map. Defined using ':imap' or ':inoremap'.
-- v  Visual and select mode map. Defined using ':vmap' or ':vnoremap'.
-- x  Visual mode map. Defined using ':xmap' or ':xnoremap'.
-- s  Select mode map. Defined using ':smap' or ':snoremap'.
-- c  Command-line mode map. Defined using ':cmap' or ':cnoremap'.
-- o  Operator pending mode map. Defined using ':omap' or ':onoremap'.

-- NOTE: entries marked `-- UNUSED` are not referenced by any keymap yet,
-- so changing them has no effect until something consumes them.

return {
  --
  -- Search and replace
  -- UNUSED: nothing references the `searchReplace` group
  --
  searchReplace = {
    replaceWord = {
      desc = "Replace word",
      mode = "n",
      shortcut = "<leader>r",
    },
    replaceSelected = {
      desc = "Change the selection (repeatable action for other occurences)",
      mode = "v",
      shortcut = "<leader>r",
    },
    searchInSelected = {
      desc = "Search within the selection",
      mode = "v",
      shortcut = "<leader>/",
    },
    substiteSubstring = {
      desc = "Substite substring",
      mode = "x",
      shortcut = "<leader>v",
    },
  },

  --
  -- Misc
  --
  misc = {
    -- UNUSED: not wired to any keymap
    deleteBlackHole = {
      desc = "Delete (black hole)",
      mode = { "n", "v" },
      shortcut = "<M-d>",
    },
    diffWin = {
      desc = "Diff windows",
      mode = "n",
      shortcut = "<leader>dw",
    },
    diffWinQuit = {
      desc = "Quit diff windows",
      mode = "n",
      shortcut = "<leader>dq",
    },
  },

  --
  -- Harpoon
  -- UNUSED: the plugin is mapped with hardcoded keys in lua/plugins/coding.lua
  --
  harpoon = {
    list = {
      desc = "Toggle harpoon list",
      mode = "n",
      shortcut = "<M-b>",
    },
    mark = {
      desc = "Un/Mark the current file in Harpoon",
      mode = "n",
      shortcut = "<M-a>",
    },
    shortcuts = {
      "<M-q>",
      "<M-w>",
      "<M-e>",
      "<M-r>",
      "<M-t>",
    },
    prev = {
      mode = "n",
      shortcut = "<M-Left>",
      desc = "Prev harpoon mark",
    },
    next = {
      mode = "n",
      shortcut = "<M-Right>",
      desc = "Next harpoon mark",
    },
    clear = {
      desc = "Remove all harpoon marks",
      mode = "n",
      shortcut = "<M-x>",
    },
  },

  --
  -- Explorer
  -- Only `floatingExplorer` is wired up (lua/plugins/snacks/explorer.lua).
  -- The rest is left over from the Neo-tree setup.
  --
  explorer = {
    -- UNUSED: not wired to any keymap
    showInCurrent = {
      mode = "n",
      shortcut = "-",
      desc = "Show explorer in the current window",
    },
    floatingExplorer = {
      desc = "Floating Explorer (root dir)",
      mode = "n",
      shortcut = "<M-'>",
    },
    -- showSidebarExplorer = {
    --   desc = "Show sidebar explorer",
    --   mode = "n",
    --   shortcut = "<C-'>",
    -- },
    -- UNUSED: not wired to any keymap
    hideSidebarExplorer = {
      desc = "Hide sidebar explorer",
      mode = "n",
      shortcut = "<C-c>",
    },
    -- UNUSED: not wired to any keymap
    prevSibling = {
      desc = "Jump to the previous sibling",
      mode = "n",
      shortcut = "K",
    },
    -- UNUSED: not wired to any keymap
    nextSibling = {
      desc = "Jump to the next sibling",
      mode = "n",
      shortcut = "J",
    },
    -- UNUSED: not wired to any keymap
    split = {
      desc = "Open file in the new window (horizontal split)",
      mode = "n",
      shortcut = "<C-s>",
    },
    -- UNUSED: not wired to any keymap
    vsplit = {
      desc = "Open file in the new window (vertical split)",
      mode = "n",
      shortcut = "<C-v>",
    },
    -- UNUSED: not wired to any keymap
    grepInSelected = {
      desc = "Grep search in the selected folder",
      mode = "n",
      shortcut = "tg",
    },
    -- UNUSED: not wired to any keymap
    findInSelected = {
      desc = "Find in files of the selected folder",
      mode = "n",
      shortcut = "tf",
    },
    -- UNUSED: not wired to any keymap
    close = {
      desc = "Close explorer",
      mode = { "n", "i" },
      shortcut = "<C-c>",
    },
  },

  --
  -- Telescope
  -- UNUSED: replaced by the Snacks picker (`snacks` group below)
  --
  telescope = {
    recentFiles = {
      title = "Recent files",
      desc = "Show recently used files",
      mode = "n",
      shortcut = "<M-,>",
    },
    recentFilesCwd = {
      title = "Recent files (cwd)",
      desc = "Show recently used files (cwd)",
      mode = "n",
      shortcut = "<M-<>",
    },
    liveGrepFuzzyRefine = {
      desc = "Fuzzy refine the searched expression",
      mode = "i",
      shortcut = "<C-f>",
    },
    findHiddenIncluded = {
      desc = "Find in files (hiddens included)",
      mode = "n",
      shortcut = "<leader>fh",
    },
    showQuickfixLists = {
      desc = "Browse opened quickfix lists",
      mode = "n",
      shortcut = "<leader>fq",
    },
    openWindowPicker = {
      desc = "Open with window picker",
      mode = { "n", "i" },
      shortcut = "<C-o>",
    },
    togglePreview = {
      desc = "Toggle file preview",
      mode = { "n", "i" },
      shortcut = "<C-p>",
    },
    close = {
      desc = "Close picker",
      mode = { "n", "i" },
      shortcut = "<C-c>",
    },
  },

  --
  -- Git
  --
  git = {
    fileHistory = {
      desc = "The current file history",
      mode = "n",
      shortcut = "<leader>gf",
    },
    branchHistory = {
      desc = "The current branch history",
      mode = "n",
      shortcut = "<leader>gD",
    },
    closeHistory = {
      desc = "Close diffview history",
      mode = "n",
      shortcut = "<leader>gq",
    },
    openCommitFile = {
      desc = "Open file at commit revision via fugitive",
      mode = "n",
      shortcut = "gf",
    },
    closeDiffviewAndOpenFile = {
      desc = "Close diffview and open the file in its window",
      mode = "n",
      shortcut = "<C-w>gx",
    },
    prevConflict = {
      desc = "In the merge-tool: jump to the prev conflict",
      mode = "n",
      shortcut = "<M-Left>",
    },
    nextConflict = {
      desc = "In the merge-tool: jump to the next conflict",
      mode = "n",
      shortcut = "<M-Right>",
    },
    fastForward = {
      desc = "Fast-forward",
      mode = "n",
      shortcut = "<leader>go",
    },
    traceLineEvolution = {
      desc = "Trace line evolution",
      mode = "v",
      shortcut = "<leader>gv",
    },
    uncommitedChanges = {
      desc = "Uncommited changes",
      mode = "n",
      shortcut = "<leader>gu",
    },
    review = {
      desc = "Review PR",
      mode = "n",
      shortcut = "<leader>gr",
    },
    branchChanges = {
      desc = "Branch changes",
      mode = "n",
      shortcut = "<leader>gp",
    },
    grepBranchFiles = {
      desc = "Grep branch and working-tree changes",
      mode = "n",
      shortcut = "<leader>ga",
    },
  },

  --
  -- Snacks picker and explorer
  --
  snacks = {
    picker = {
      findFiles = {
        desc = "Find files",
        mode = "n",
        shortcut = "<M-,>",
      },
      cancel = {
        desc = "Cancel picker",
        mode = { "n", "i", "x" },
        shortcut = "<C-c>",
      },
      togglePreview = {
        desc = "Toggle preview",
        mode = { "n", "i" },
        shortcut = "<a-p>",
      },
      cyclePreview = {
        desc = "Cycle preview layout",
        mode = "n",
        shortcut = "<C-p>",
      },
    },
    explorer = {
      show = {
        desc = "Show explorer",
        mode = "n",
        shortcut = "<M-\\>",
      },
      setWorkingDirectory = {
        desc = "Set tab working directory",
        mode = { "n", "i" },
        shortcut = "<C-g>",
      },
      toggleGitStatus = {
        desc = "Toggle Git-changed files only",
        mode = { "n", "i" },
        shortcut = "S",
      },
    },
    gitLog = {
      openFile = {
        desc = "Open File",
        mode = { "n", "i" },
        shortcut = "<CR>",
      },
      openDiffview = {
        desc = "Open Diffview (commit)",
        mode = { "n", "i" },
        shortcut = "<M-g>",
      },
    },
  },

  --
  -- Misc reference operations
  --
  references = {
    -- UNUSED: not wired to any keymap
    openInFinder = {
      desc = "Open parent directory in Finder",
      mode = "n",
      shortcut = "<leader>oe",
    },
    openInBrowser = {
      desc = "Open file in the browser",
      mode = "n",
      shortcut = "<leader>oo",
    },
    -- UNUSED: not wired to any keymap
    copyUrl = {
      desc = "Copy repo url",
      mode = "n",
      shortcut = "<leader>ou",
    },
    -- UNUSED: not wired to any keymap
    copyBranchname = {
      desc = "Copy branch name",
      mode = "n",
      shortcut = "<leader>ob",
    },
    copyBufferName = {
      desc = "Copy buffer filename",
      mode = "n",
      shortcut = "<leader>om",
    },
    copyFilepath = {
      desc = "Copy path to the current file",
      mode = "n",
      shortcut = "<leader>op",
    },
    copyFileLink = {
      desc = "Copy link to the current file",
      mode = { "n", "v" },
      shortcut = "<leader>of",
    },
    copyLineLink = {
      desc = "Copy link to the current line/range",
      mode = { "n", "v" },
      shortcut = "<leader>ol",
    },
    copyLineRef = {
      desc = "Copy relative path with line/range (path#L10)",
      mode = { "n", "v" },
      shortcut = "<leader>or",
    },
  },

  --
  -- Code notes (scratch buffer of references + notes)
  --
  notes = {
    add = {
      desc = "Add code note (reference + note)",
      mode = { "n", "v" },
      shortcut = "<leader>on",
    },
    addFile = {
      desc = "Add code note for the whole file",
      mode = "n",
      shortcut = "<leader>oF",
    },
    addSnippet = {
      desc = "Add line/selection as a code snippet to notes",
      mode = { "n", "v" },
      shortcut = "<leader>oc",
    },
    open = {
      desc = "Open/focus code notes window",
      mode = "n",
      shortcut = "<leader>oN",
    },
    copy = {
      desc = "Copy all code notes to clipboard",
      mode = "n",
      shortcut = "<leader>oy",
    },
    save = {
      desc = "Save code notes for the current project",
      mode = "n",
      shortcut = "<leader>os",
    },
    load = {
      desc = "Load code notes for the current project",
      mode = "n",
      shortcut = "<leader>ol",
    },
    close = {
      desc = "Close code notes window",
      mode = "n",
      shortcut = "<leader>oq",
    },
    -- Buffer-local keys, active only inside the code notes buffer.
    jump = {
      desc = "Jump to the reference under the cursor",
      mode = { "n", "x" },
      shortcut = "<CR>",
    },
    next = {
      desc = "Select the next reference",
      mode = { "n", "x" },
      shortcut = "<Tab>",
    },
    prev = {
      desc = "Select the previous reference",
      mode = { "n", "x" },
      shortcut = "<S-Tab>",
    },
  },

  --
  -- Code completion
  -- UNUSED: blink.cmp uses its own keymap preset (lua/plugins/cmp.lua)
  --
  completion = {
    show = {
      mode = "i",
      shortcut = "<C-space>",
      desc = "Show completion list",
    },
    next = {
      mode = "i",
      shortcut = "<C-n>",
    },
    prev = {
      mode = "i",
      shortcut = "<C-p>",
    },
    accept = {
      mode = "i",
      shortcut = "<C-y>",
    },
  },

  --
  -- Snippets
  --
  snippet = {
    -- UNUSED: not wired to any keymap
    add = {
      desc = "Add new snippet",
      mode = { "n", "x" },
      shortcut = "<leader>cn",
    },
    -- UNUSED: not wired to any keymap
    edit = {
      desc = "Edit snippet",
      mode = "n",
      shortcut = "<leader>ce",
    },
    jumpNext = {
      desc = "Jump to the next placeholder",
      mode = { "s", "i" },
      shortcut = "<m-j>",
    },
    jumpPrev = {
      desc = "Jump to the previous placeholder",
      mode = { "s", "i" },
      shortcut = "<m-k>",
    },
  },

  --
  -- LSP
  --
  lsp = {
    -- UNUSED: not wired to any keymap (LazyVim sets its own gd/gr/gy/gI)
    goToDefinition = {
      mode = "n",
      shortcut = "gd",
      desc = "Go to definition",
    },
    -- UNUSED: not wired to any keymap
    goToTypeDefinition = {
      desc = "Go to type definition",
      mode = "n",
      shortcut = "gy",
    },
    -- UNUSED: not wired to any keymap
    goToImplementation = {
      desc = "Go to implementation",
      mode = "n",
      shortcut = "gi",
    },
    -- UNUSED: not wired to any keymap
    goToReferences = {
      desc = "Go to references",
      mode = "n",
      shortcut = "gr",
    },
    showDiagWindow = {
      desc = "Show diag. in a floating window.",
      mode = "n",
      shortcut = "<leader>h",
    },
    -- UNUSED: not wired to any keymap
    outlineSymbols = {
      desc = "Outline symbols",
      mode = "n",
      shortcut = "<leader>co",
    },
    -- UNUSED: not wired to any keymap
    renameSymbol = {
      desc = "Rename symbol",
      mode = "n",
      shortcut = "<leader>cr",
    },
    -- UNUSED: not wired to any keymap
    codeAction = {
      desc = "Code action",
      mode = { "x", "n" },
      shortcut = "<leader>ca",
    },
    eslintFixAll = {
      desc = "Fix all ESLint problems",
      mode = "n",
      shortcut = "<leader>cu",
    },
    -- UNUSED: not wired to any keymap
    sourceAction = {
      desc = "Source action",
      mode = "n",
      shortcut = "<leader>cA",
    },
    -- UNUSED: not wired to any keymap
    diagList = {
      desc = "Show diagnostics",
      mode = "n",
      shortcut = "<leader>xx",
    },
    hoverInfo = {
      desc = "Show info",
      mode = "n",
      shortcut = "H",
    },
    log = {
      desc = "LSP logs",
      mode = "n",
      shortcut = "<leader>xd",
    },
    info = {
      desc = "LSP info",
      mode = "n",
      shortcut = "<leader>xi",
    },
    restart = {
      desc = "Restart LSP",
      mode = "n",
      shortcut = "<leader>xr",
    },
    -- UNUSED: not wired to any keymap
    format = {
      desc = "Format",
      mode = { "x", "n" },
      shortcut = "<leader>cf",
    },
    -- UNUSED: not wired to any keymap (same key as outlineSymbols)
    organizeImports = {
      desc = "Organize imports",
      mode = "n",
      shortcut = "<leader>co",
    },
    -- UNUSED: not wired to any keymap
    renameFile = {
      desc = "Rename file (refs updated)",
      mode = "n",
      shortcut = "<leader>cR",
    },
    prevRef = {
      desc = "Prev reference",
      mode = "n",
      shortcut = "<M-p>",
    },
    nextRef = {
      desc = "Next reference",
      mode = "n",
      shortcut = "<M-n>",
    },
  },

  ai = {
    accept_word = {
      shortcut = "<M-l>",
    },
    accept_line = {
      shortcut = "<M-o>",
    },
    accept = {
      shortcut = "<M-y>",
    },
    prev = {
      shortcut = "<M-p>",
    },
    next = {
      shortcut = "<M-n>",
    },
    dismiss = {
      shortcut = "<M-e>",
    },
  },
}
