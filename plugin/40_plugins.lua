-- ┌─────────────────────────┐
-- │ Plugins outside of MINI │
-- └─────────────────────────┘
--
-- This file contains installation and configuration of plugins outside of MINI.
-- They significantly improve user experience in a way not yet possible with MINI.
-- These are mostly plugins that provide programming language specific behavior.
--
-- Use this file to install and configure other such plugins.

-- Make concise helpers for installing/adding plugins in two stages
local add, later = MiniDeps.add, MiniDeps.later
local now_if_args = _G.Config.now_if_args

-- Tree-sitter ================================================================

-- Tree-sitter is a tool for fast incremental parsing. It converts text into
-- a hierarchical structure (called tree) that can be used to implement advanced
-- and/or more precise actions: syntax highlighting, textobjects, indent, etc.
--
-- Tree-sitter support is built into Neovim (see `:h treesitter`). However, it
-- requires two extra pieces that don't come with Neovim directly:
-- - Language parsers: programs that convert text into trees. Some are built-in
--   (like for Lua), 'nvim-treesitter' provides many others.
--   NOTE: It requires third party software to build and install parsers.
--   See the link for more info in "Requirements" section of the MiniMax README.
-- - Query files: definitions of how to extract information from trees in
--   a useful manner (see `:h treesitter-query`). 'nvim-treesitter' also provides
--   these, while 'nvim-treesitter-textobjects' provides the ones for Neovim
--   textobjects (see `:h text-objects`, `:h MiniAi.gen_spec.treesitter()`).
--
-- Add these plugins now if file (and not 'mini.starter') is shown after startup.
now_if_args(function()
  add({
    source = 'nvim-treesitter/nvim-treesitter',
    -- Use `main` branch since `master` branch is frozen, yet still default
    checkout = 'main',
    -- Update tree-sitter parser after plugin is updated
    hooks = { post_checkout = function() vim.cmd('TSUpdate') end },
  })
  add({
    source = 'nvim-treesitter/nvim-treesitter-textobjects',
    -- Same logic as for 'nvim-treesitter'
    checkout = 'main',
  })

  -- Define languages which will have parsers installed and auto enabled
  local languages = {
    -- These are already pre-installed with Neovim. Used as an example.
    'lua',
    'vimdoc',
    'markdown',
    'terraform',
    'python',
    'yaml',
    'json',
    'bash',
    'javascript',
    'typescript',
    -- Add here more languages with which you want to use tree-sitter
    -- To see available languages:
    -- - Execute `:=require('nvim-treesitter').get_available()`
    -- - Visit 'SUPPORTED_LANGUAGES.md' file at
    --   https://github.com/nvim-treesitter/nvim-treesitter/blob/main
  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file('parser/' .. lang .. '.*', false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then require('nvim-treesitter').install(to_install) end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev) vim.treesitter.start(ev.buf) end
  _G.Config.new_autocmd('FileType', filetypes, ts_start, 'Start tree-sitter')
end)

-- Language servers ===========================================================

-- Language Server Protocol (LSP) is a set of conventions that power creation of
-- language specific tools. It requires two parts:
-- - Server - program that performs language specific computations.
-- - Client - program that asks server for computations and shows results.
--
-- Here Neovim itself is a client (see `:h vim.lsp`). Language servers need to
-- be installed separately based on your OS, CLI tools, and preferences.
-- See note about 'mason.nvim' at the bottom of the file.
--
-- Neovim's team collects commonly used configurations for most language servers
-- inside 'neovim/nvim-lspconfig' plugin.
--
-- Add it now if file (and not 'mini.starter') is shown after startup.
now_if_args(function()
  add('neovim/nvim-lspconfig')
end)
  -- add('lua_ls')

  -- Use `:h vim.lsp.enable()` to automatically enable language server based on
  -- the rules provided by 'nvim-lspconfig'.
  -- Use `:h vim.lsp.config()` or 'after/lsp/' directory to configure servers.
  -- Uncomment and tweak the following `vim.lsp.enable()` call to enable servers.
  -- vim.lsp.enable({
  --   -- For example, if `lua-language-server` is installed, use `'lua_ls'` entry
  -- })
-- end)

-- Formatting =================================================================

-- Programs dedicated to text formatting (a.k.a. formatters) are very useful.
-- Neovim has built-in tools for text formatting (see `:h gq` and `:h 'formatprg'`).
-- They can be used to configure external programs, but it might become tedious.
--
-- The 'stevearc/conform.nvim' plugin is a good and maintained solution for easier
-- formatting setup.
--
-- Auto-formatting behavior inspired by LazyVim:
-- - Formats on save by default
-- - Can be toggled globally with <Leader>uf or per-buffer with <Leader>uF
later(function()
  add('stevearc/conform.nvim')

  -- Global auto-format state (enabled by default)
  vim.g.autoformat = true

  -- See also:
  -- - `:h Conform`
  -- - `:h conform-options`
  -- - `:h conform-formatters`
  require('conform').setup({
    -- Map of filetype to formatters
    -- Make sure that necessary CLI tool is available (install via Mason or system)
    formatters_by_ft = {
      lua = { 'stylua' },
      python = { 'ruff_format', 'ruff_organize_imports' },
      go = { 'goimports', 'gofmt' },
      terraform = { 'terraform_fmt' },
      tf = { 'terraform_fmt' },
      ['terraform-vars'] = { 'terraform_fmt' },
      yaml = { 'prettier' },
      json = { 'prettier' },
      jsonc = { 'prettier' },
      markdown = { 'prettier' },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      -- Use LSP formatting as fallback for filetypes without dedicated formatter
      ['_'] = { 'trim_whitespace' },
    },

    -- Format on save with timeout
    format_on_save = function(bufnr)
      -- Check buffer-local toggle (takes precedence)
      local bufvar = vim.b[bufnr].autoformat
      if bufvar ~= nil then
        if not bufvar then return end
      elseif not vim.g.autoformat then
        -- Check global toggle
        return
      end
      return { timeout_ms = 3000, lsp_format = 'fallback' }
    end,

    -- Customize formatters
    formatters = {
      shfmt = {
        prepend_args = { '-i', '2' }, -- 2 space indent
      },
    },
  })
end)

-- Snippets ===================================================================

-- Although 'mini.snippets' provides functionality to manage snippet files, it
-- deliberately doesn't come with those.
--
-- The 'rafamadriz/friendly-snippets' is currently the largest collection of
-- snippet files. They are organized in 'snippets/' directory (mostly) per language.
-- 'mini.snippets' is designed to work with it as seamlessly as possible.
-- See `:h MiniSnippets.gen_loader.from_lang()`.
-- TODO: 1. keybinds
local pluglist = {
  "ThePrimeagen/harpoon",
  "jackMort/ChatGPT.nvim",
  "jesseduffield/lazygit",
  "munifTanjim/nui.nvim",
  "nvim-lua/plenary.nvim",
  "nvim-telescope/telescope-frecency.nvim",
  "nvim-telescope/telescope.nvim",
  "rafamadriz/friendly-snippets",
  "ryanmsnyder/toggleterm-manager.nvim",
  "tpope/vim-dadbod",
  "tpope/vim-surround",
  "vimwiki/vimwiki",
  "folke/noice.nvim.git",
  -- "hrsh7th/nvim-cmp",
}

for _, plugin in ipairs(pluglist) do 
  later(function() add(plugin) end)
end

-- Neo-tree ==================================================================

-- File tree explorer sidebar. Requires plenary.nvim and nui.nvim (already
-- in pluglist above). nvim-web-devicons provides file icons.
later(function()
  add('nvim-tree/nvim-web-devicons')
  add({
    source = 'nvim-neo-tree/neo-tree.nvim',
    checkout = 'v3.x',
  })

  require('neo-tree').setup({
    close_if_last_window = true,
    filesystem = {
      follow_current_file = { enabled = true },
      hijack_netrw_behavior = 'open_current',
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    window = {
      width = 35,
      mappings = {
        ['<space>'] = 'none',
      },
    },
  })
end)

-- honorable mentions =========================================================

-- 'mason-org/mason.nvim' (a.k.a. "mason") is a great tool (package manager) for
-- installing external language servers, formatters, and linters. It provides
-- a unified interface for installing, updating, and deleting such programs.
--
-- The caveat is that these programs will be set up to be mostly used inside Neovim.
-- If you need them to work elsewhere, consider using other package managers.
--
-- You can use it like so:
later(function()
  add('mason-org/mason.nvim')
  require('mason').setup()
end)

-- GitHub Copilot ============================================================
--
-- AI-powered code completion. Provides inline suggestions as you type.
-- Requires GitHub Copilot subscription and authentication.
--
-- First-time setup:
-- 1. Run `:Copilot auth` to authenticate with GitHub
-- 2. Follow the browser prompts to authorize
--
-- Usage:
-- - Suggestions appear as virtual text (grayed out) as you type
-- - `<M-l>` (Alt+l) - Accept suggestion
-- - `<M-]>` - Next suggestion
-- - `<M-[>` - Previous suggestion
-- - `<C-]>` - Dismiss suggestion
-- - `:Copilot panel` - Open suggestions panel
--
-- See also:
-- - `:h copilot` - Plugin documentation
later(function()
  add('zbirenbaum/copilot.lua')

  require('copilot').setup({
    -- Disable default Tab mapping to avoid conflict with mini.completion
    suggestion = {
      enabled = true,
      auto_trigger = true,
      debounce = 75,
      keymap = {
        accept = false,         -- Handled by MiniKeymap with pmenu fallback
        accept_word = '<M-w>',  -- Alt+w to accept word
        accept_line = '<M-j>',  -- Alt+j to accept line
        next = '<M-]>',         -- Alt+] for next suggestion
        prev = '<M-[>',         -- Alt+[ for previous suggestion
        dismiss = '<C-]>',      -- Ctrl+] to dismiss
      },
    },
    panel = {
      enabled = true,
      auto_refresh = true,
      keymap = {
        jump_prev = '[[',
        jump_next = ']]',
        accept = '<CR>',
        refresh = 'gr',
        open = '<M-CR>',        -- Alt+Enter to open panel
      },
    },
    filetypes = {
      -- Enable for your main languages
      terraform = true,
      python = true,
      go = true,
      yaml = true,
      json = true,
      markdown = true,
      lua = true,
      sh = true,
      bash = true,
      -- Disable for these
      gitcommit = false,
      gitrebase = false,
      help = false,
      ['*'] = true,             -- Enable for all other filetypes
    },
  })
end)

later(function()
  -- config = function()
  add('jackMort/ChatGPT.nvim')
  require('chatgpt').setup()
end)

later(function()
  add('folke/noice.nvim.git')
  require('noice').setup({
    popupmenu = {
      enabled = false,
    },
    lsp = {
      hover = { enabled = false },
      signature = { enabled = false },
      progress = { enabled = false },
      message = { enabled = false },
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = false,
        ["vim.lsp.util.stylize_markdown"] = false,
        ["cmp.entry.get_documentation"] = false,
      },
    },
    routes = {
      -- Show macro recording messages in cmdline
      {
        view = "cmdline",
        filter = { event = "msg_showmode" },
      },
    },
  })
end)

require('mini.hues').setup({
  background = '#2f1c22',
  foreground = '#cdc4c6',
  plugins = {
    default = false,
    ['nvim-mini/mini.nvim'] = true,
  },
})

-- Beautiful, usable, well maintained color schemes outside of 'mini.nvim' and
-- have full support of its highlight groups. Use if you don't like 'miniwinter'
-- enabled in 'plugin/30_mini.lua' or other suggested 'mini.hues' based ones.
MiniDeps.now(function()
  -- Install only those that you need
  add('tiagovla/tokyodark.nvim')
  add('catppuccin/nvim')
  add('EdenEast/nightfox.nvim')
  add('ellisonleao/gruvbox.nvim')
  add('Mofiqul/dracula.nvim')

  -- Enable only one
vim.cmd('color tokyodark')
end)
