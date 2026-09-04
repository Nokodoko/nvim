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
    'markdown_inline',
    'terraform',
    'python',
    'yaml',
    'json',
    'bash',
    'javascript',
    'typescript',

    -- Extra languages for fenced code block highlighting in markdown
    'go',
    'html',
    'css',
    'toml',
    'dockerfile',
    'rust',
    'c',
    'cpp',
    'sql',
    'regex',
    'diff',
    'vim',
    'xml',
    'graphql',
    'make',

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
  -- Paths that must NEVER be auto-formatted, as Lua patterns matched against
  -- the buffer's full path. Prettier rewrites markdown emphasis characters:
  -- `adp_` becomes `adp\_`, and a pair like `adp_ authy_` becomes `adp* authy*`.
  -- That corrupts the key lines in ~/.pass/pass.md, and parse_pass.sh (which
  -- strips one trailing `_`/`*`) then yields a key of `adp\`.
  local format_protected = {
    '/%.pass/', -- password store
  }

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
      -- Protected paths win over every toggle.
      local path = vim.api.nvim_buf_get_name(bufnr)
      for _, pat in ipairs(format_protected) do
        if path:match(pat) then return end
      end
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
      prettier = {
        prepend_args = function(_, ctx)
          if vim.bo[ctx.buf].filetype == 'markdown' then
            return { '--print-width', '85', '--prose-wrap', 'preserve' }
          end
          return {}
        end,
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
-- Vimwiki: prevent hijacking all .md files as vimwiki filetype.
-- Only files inside a registered wiki directory will be treated as vimwiki.
-- This is critical for treesitter fenced code block injection highlighting.
vim.g.vimwiki_global_ext = 0

-- TODO: 1. keybinds
local pluglist = {
  "ThePrimeagen/harpoon",
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

-- telescope-cmdr.nvim =======================================================
-- Telescope pickers for computeCommander: agents, sessions, mail, merge, etc.
-- Host-gated: cmdr is a Linux-only orchestration tool. The plugin path lives
-- under ~/Programs/ai/computeCommander which only exists on lewis. Skip the
-- entire load + keybinds on hosts where the plugin directory is missing so
-- mac/other machines launch nvim cleanly.
later(function()
  local cmdr_plugin = vim.fn.expand('~/Programs/ai/computeCommander/.claude/worktrees/telescope/plugins/telescope-cmdr.nvim')
  if vim.fn.isdirectory(cmdr_plugin) == 0 then
    return
  end
  add({ source = 'nvim-telescope/telescope.nvim' }) -- ensure telescope loaded first
  vim.opt.runtimepath:prepend(cmdr_plugin)
  package.path = cmdr_plugin .. '/lua/?.lua;' .. cmdr_plugin .. '/lua/?/init.lua;' .. package.path
  require('telescope').load_extension('cmdr')
  -- telescope-cmdr.nvim keybinds
  vim.keymap.set('n', '<C-k>', function()
    require('telescope').extensions.cmdr.commands()
  end, { desc = 'cmdr: Command Palette' })
  vim.keymap.set('i', '<C-k>', function()
    vim.cmd('stopinsert')
    require('telescope').extensions.cmdr.commands()
  end, { desc = 'cmdr: Command Palette' })
end)

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

-- minuet-ai.nvim (local inline completion) ==================================
-- nvim-model:managed model=qwen3-next-80b-tp2 host=cai:8090
--
-- Replaces GitHub Copilot with the local llama.cpp server on `cai`
-- (Qwen3-30B-A3B-Instruct-2507, 98k ctx). copilot.lua could NOT be reused:
-- its config surface (auth_provider_url / copilot_model / server.custom_
-- server_filepath) has no inference-endpoint knob -- it always speaks
-- GitHub's proprietary Copilot LSP protocol. minuet's `openai_compatible`
-- provider takes a raw end_point, so it talks to llama.cpp directly.
--
-- No subscription and no `:Copilot auth` step -- llama.cpp ignores the
-- bearer token, so api_key returns a constant. (minuet treats a STRING
-- api_key as an env-var *name* and a FUNCTION as the literal key --
-- see minuet/utils.lua get_api_key.)
--
-- Usage:
-- - MANUAL TRIGGER ONLY (auto-trigger froze the UI ~5s per request):
--   `<M-.>` / `<M-,>` in insert mode request a suggestion on demand
-- - Suggestions appear as virtual text (grayed out) once requested
-- - `<C-l>` - Accept suggestion (via MiniKeymap, see 30_mini.lua)
-- - `<M-j>` - Accept one line
-- - `<M-w>` - Accept N lines (prompts for N; minuet has no accept_word)
-- - `<C-]>` - Dismiss suggestion
-- - `<leader>uc` - toggle auto-trigger (no-op unless auto_trigger_ft set)
-- - `<leader>uk` - open the keybind cheat sheet (see plugin/70_cheatsheet.lua)
--
-- See also:
-- - `:h minuet` - Plugin documentation
-- - `/nvim-model <model> <host>` - repoint this + ChatGPT.nvim at a new model
later(function()
  add('milanglacier/minuet-ai.nvim')

  -- Filetypes where an inline suggestion is just noise. Everything else --
  -- INCLUDING markdown -- is covered by the '*' auto_trigger_ft pattern below.
  local minuet_ignore_ft = { 'gitcommit', 'gitrebase', 'help' }

  require('minuet').setup({
    provider = 'openai_compatible',
    provider_options = {
      openai_compatible = {
        end_point = 'http://cai:8090/v1/chat/completions',
        model = 'qwen3-next-80b-tp2',
        name = 'cai',
        -- Function form => used verbatim as the key. llama.cpp ignores it,
        -- but minuet aborts the request when the key resolves to nil.
        api_key = function() return 'local-no-auth' end,
        stream = true,
        optional = {
          max_tokens = 256,
        },
      },
    },

    -- Latency budget, measured on cai (llama.cpp/Vulkan): ~1884 tok/s prompt
    -- eval, ~69 tok/s generation.
    --
    -- request_timeout becomes curl `--max-time`. The 3s default killed EVERY
    -- request on a real buffer: a 26k-char context is ~9900 prompt tokens and
    -- needs ~9s end to end. Nothing streams until prompt eval completes (5.3s),
    -- so a 3s cap produced zero tokens rather than a partial completion.
    request_timeout = 30,
    -- The chat backend encodes n_completions candidates into ONE response, so
    -- the default of 3 costs ~3x the generation time. One keeps it responsive.
    n_completions = 1,
    -- Halved from the 16000 default to cut prompt eval roughly in half.
    -- Split context_ratio 0.75 before the cursor / 0.25 after.
    context_window = 8000,

    virtualtext = {
      -- Manual trigger only: auto-trigger caused ~5s UI freezes while the
      -- llama.cpp prompt eval blocked redraws. Invoke with <M-]> (next) or
      -- <M-[> (prev) in insert mode; manual invocation works in ANY filetype.
      auto_trigger_ft = {},
      auto_trigger_ignore_ft = minuet_ignore_ft,
      -- mini.completion auto-triggers its popup constantly; at the default of
      -- false the grey virtual text would be suppressed nearly all the time.
      show_on_completion_menu = true,
      keymap = {
        accept = nil,               -- Handled by MiniKeymap with pmenu fallback
        accept_line = '<M-j>',      -- Alt+j to accept line
        accept_n_lines = '<M-w>',   -- Alt+w to accept N lines
        next = '<M-.>',             -- Alt+. to request/cycle next suggestion
        prev = '<M-,>',             -- Alt+, to request/cycle previous suggestion
        dismiss = '<C-]>',          -- Ctrl+] to dismiss
      },
    },
  })

  -- Manual-trigger mode: no buffer arming. `action.next`/`action.prev` fire a
  -- request on demand even when auto-trigger is off, in any filetype. Do NOT
  -- set vim.b.minuet_virtual_text_auto_trigger here -- arming buffers is what
  -- re-enabled auto-trigger and brought back the ~5s UI freezes (the leftover
  -- arming loop from the auto-trigger era was removed for exactly that reason).
end)

-- ChatGPT.nvim ==============================================================
-- nvim-model:managed model=qwen3-next-80b-tp2 host=cai:8090
-- Pointed at the local llama.cpp server on `cai` (Qwen3-30B-A3B-Instruct-2507,
-- 98k ctx) instead of the OpenAI API. The endpoint is OpenAI-compatible, so
-- only the host + model ids change.
--
-- Host resolution order (chatgpt/api.lua loadOptionalConfig):
--   1. $OPENAI_API_HOST if set   2. api_host_cmd below
-- so exporting OPENAI_API_HOST overrides this without editing the repo.
--
-- api_key_cmd is mandatory -- loadRequiredConfig warns and bails without a
-- key. llama.cpp ignores the bearer token, so any non-empty string works.
-- NOTE: *_cmd strings are split on whitespace and exec'd directly (no shell),
-- so shell syntax (${VAR:-x}, pipes, globs) will NOT expand here.
later(function()
  add('jackMort/ChatGPT.nvim')
  require('chatgpt').setup({
    api_host_cmd = 'echo http://cai:8090',
    api_key_cmd = 'echo local-no-auth',
    loading_text = 'loading',
    question_sign = '',
    answer_sign = 'ﮧ',
    max_line_length = 120,
    yank_register = '+',
    chat_layout = {
      relative = 'editor',
      position = '50%',
      size = { height = '80%', width = '80%' },
    },
    settings_window = {
      border = { style = 'rounded', text = { top = ' Settings ' } },
    },
    chat_window = {
      filetype = 'chatgpt',
      border = {
        highlight = 'FloatBorder',
        style = 'rounded',
        text = { top = ' qwen3-next-80b-tp2 @ cai:8090 ' }, -- nvim-model:title
      },
    },
    chat_input = {
      prompt = '  ',
      border = {
        highlight = 'FloatBorder',
        style = 'rounded',
        text = { top_align = 'center', top = ' Prompt ' },
      },
    },
    openai_params = {
      model = 'qwen3-next-80b-tp2',
      frequency_penalty = 0,
      presence_penalty = 0,
      max_tokens = 4096,
      temperature = 0,
      top_p = 1,
      n = 1,
    },
    openai_edit_params = {
      model = 'qwen3-next-80b-tp2',
      temperature = 0,
      top_p = 1,
      n = 1,
    },
    keymaps = {
      close = { '<C-c>', '<Esc>' },
      yank_last = '<C-y>',
      scroll_up = '<C-u>',
      scroll_down = '<C-d>',
      toggle_settings = '<C-o>',
      new_session = '<C-n>',
      cycle_windows = '<Tab>',
      submit = '<Enter>',
      submit_n = '<C-Enter>',
    },
  })
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
    views = {
      cmdline_input = {
        relative = "cursor",
        position = { row = 1, col = 0 },
        size = { width = 60 },
        border = { style = "single" },
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
