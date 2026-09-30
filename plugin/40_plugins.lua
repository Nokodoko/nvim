-- bisect guard: nvim --cmd "let g:skip_plugins = ['40_plugins']" skips this file
if vim.g.skip_plugins and vim.tbl_contains(vim.g.skip_plugins, '40_plugins') then return end
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
  "kdheepak/lazygit.nvim",
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
-- nvim-model:managed model=qwen3.8-flash-next host=monty:8085
--
-- Replaces GitHub Copilot with the Qwen3.8-Flash-Next llama.cpp server on
-- `monty` -- the same weights the :Icarus chat and the icarus harness run, so
-- completion, chat and the agents all reason over one model. copilot.lua could
-- NOT be reused: its config surface (auth_provider_url / copilot_model /
-- server.custom_server_filepath) has no inference-endpoint knob -- it always
-- speaks GitHub's proprietary Copilot LSP protocol. minuet's
-- `openai_compatible` provider takes a raw end_point, so it talks to llama.cpp
-- directly.
--
-- Why :8085 (`llamacpp-monty-qwen1`) and not :8084 (`-qwen0`): both serve
-- identical weights, but :8084 is icarus's default_provider AND its
-- tool_model_pins "*", i.e. every agent turn and tool call queues there. An
-- interactive completion should not sit behind that. :8085 only carries
-- compaction (bursty, rare) and measured marginally faster. Flip the port if
-- that ever inverts.
--
-- No subscription and no `:Copilot auth` step -- llama.cpp ignores the bearer
-- token, so api_key returns a constant. (minuet treats a STRING api_key as an
-- env-var *name* and a FUNCTION as the literal key -- see minuet/utils.lua
-- get_api_key.)
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
--
-- Kill-switch for bisecting UI problems: `nvim --cmd "let g:no_minuet = 1"`.
if vim.g.no_minuet ~= 1 then later(function()
  add('milanglacier/minuet-ai.nvim')

  -- Filetypes where an inline suggestion is just noise. Everything else --
  -- INCLUDING markdown -- is covered by the '*' auto_trigger_ft pattern below.
  local minuet_ignore_ft = { 'gitcommit', 'gitrebase', 'help' }

  require('minuet').setup({
    provider = 'openai_compatible',
    provider_options = {
      openai_compatible = {
        end_point = 'http://monty:8085/v1/chat/completions',
        model = 'qwen3.8-flash-next',
        name = 'monty',
        -- Function form => used verbatim as the key. llama.cpp ignores it,
        -- but minuet aborts the request when the key resolves to nil.
        api_key = function() return 'local-no-auth' end,
        stream = true,
        optional = {
          max_tokens = 256,
          -- MANDATORY, not cosmetic. `optional` is tbl_deep_extend'd onto the
          -- request body (minuet/backends/openai_base.lua), so this reaches
          -- llama.cpp. Qwen3.8 thinks by default, and minuet's stream/no-stream
          -- decoders read ONLY `.content` -- they never look at
          -- `reasoning_content`. Measured on monty with a real 8.4k-token
          -- buffer: thinking ON spent all 256 budget on reasoning, returned
          -- content="" with finish_reason=length, i.e. completion silently
          -- returns NOTHING. With enable_thinking=false the same request
          -- answers in ~0.2s (warm). Spelling matters: this llama.cpp build
          -- ignores the vLLM `thinking=false` form.
          chat_template_kwargs = { enable_thinking = false },
        },
        -- Follow icarus's LIVE web model (lua/icarus_endpoint.lua): minuet runs
        -- `transform` on every request, after `optional` is merged, so a
        -- /swap or /fleet in icarus repoints completion on the next keypress.
        -- The end_point/model above are only the fallback when icarus serve
        -- cannot be asked.
        transform = {
          function(req)
            local ep = require('icarus_endpoint').resolve({
              model = 'qwen3.8-flash-next', base = 'http://monty:8085', key = 'local-no-auth',
            })
            req.end_point = ep.base .. '/v1/chat/completions'
            req.headers['Authorization'] = 'Bearer ' .. ep.key
            req.body.model = ep.model
            req.body.chat_template_kwargs = require('icarus_endpoint').no_thinking
            return req
          end,
        },
      },
    },

    -- Latency budget, measured on monty:8085 (llama.cpp) 2026-09-20 with a
    -- real 8.4k-token config buffer: ~2100 tok/s prompt eval, ~90-220 tok/s
    -- generation, ~5.4s cold / ~0.2s warm end to end. (The previous cai:8090
    -- endpoint measured ~10.4s for the identical prompt -- roughly 2x slower.)
    --
    -- request_timeout becomes curl `--max-time`. The 3s default killed EVERY
    -- request on a real buffer: a 26k-char context is ~9900 prompt tokens and
    -- needs ~9s end to end. Nothing streams until prompt eval completes (5.3s),
    -- so a 3s cap produced zero tokens rather than a partial completion. Kept
    -- at 30: cold prompt eval on a large buffer still lands in seconds, and the
    -- timeout only has to cover the worst case, not the common one.
    request_timeout = 30,
    -- The chat backend encodes n_completions candidates into ONE response, so
    -- the default of 3 costs ~3x the generation time. One keeps it responsive.
    n_completions = 1,
    -- Halved from the 16000 default to cut prompt eval roughly in half.
    -- Split context_ratio 0.75 before the cursor / 0.25 after.
    context_window = 8000,

    virtualtext = {
      -- Auto-trigger everywhere but the ignore list. It was turned off on
      -- the belief that requests froze the UI ~5s; the freeze was really the
      -- synchronous curl in the markdown `models` function snippet, which
      -- mini.completion (and so every minuet request) tripped on each
      -- keystroke -- fixed in lua/icarus_models.lua (1599e07). The request
      -- path itself is the vim.loop TCP client below, off the UI loop.
      -- `nvim --cmd "let g:no_minuet = 1"` disables the plugin entirely.
      auto_trigger_ft = { '*' },
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

  -- minuet arms auto-trigger per buffer from a FileType autocmd registered in
  -- setup() (virtualtext.lua M.setup). This block runs from `later()`, so the
  -- buffers opened on the command line had their FileType fired long before
  -- that autocmd existed and would stay unarmed until re-edited. Arm them now
  -- with the same rule the autocmd applies (any filetype except the ignore
  -- list). `action.next`/`action.prev` keep working manually regardless.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.bo[bufnr].filetype
    if vim.api.nvim_buf_is_loaded(bufnr) and ft ~= '' and not vim.tbl_contains(minuet_ignore_ft, ft)
        and vim.b[bufnr].minuet_virtual_text_auto_trigger == nil then
      vim.b[bufnr].minuet_virtual_text_auto_trigger = true
    end
  end

  -- Fast path: replace minuet's per-request `curl` spawn (a synchronous
  -- fork+exec on the UI loop: ~1.5 ms warm, 15-65 ms cold -- the pause felt
  -- when a suggestion fires) with a pure vim.loop TCP client, and its
  -- full-buffer context scan with a windowed read. See lua/icarus_minuet_fast.lua
  -- for the measurements and the fallback semantics.
  require('icarus_minuet_fast').apply()
end) end

-- ChatGPT.nvim (Icarus chat) ===============================================
-- nvim-model:managed model=qwen3.8-flash-next host=monty:8084
-- The chat surface is branded "Icarus" because it talks to local inference
-- (the Qwen3.8-Flash-Next llama.cpp server on `monty`), not OpenAI. The
-- endpoint is OpenAI-compatible, so only the host + model ids differ from
-- upstream.
--
-- Host resolution order (chatgpt/api.lua loadOptionalConfig):
--   1. $OPENAI_API_HOST if set   2. api_host_cmd below
-- so exporting OPENAI_API_HOST overrides this without editing the repo.
--
-- monty:8084 is icarus's `llamacpp-monty-qwen0` (see ~/.icarus/settings.json,
-- default_provider) -- the same endpoint icarus itself runs on, so the chat
-- pane and the harness cannot drift onto different GPUs. It declares 262k ctx;
-- the sibling monty:8085 (`-qwen1`) serves the same weights at 64k.
--
-- api_key_cmd is mandatory -- loadRequiredConfig warns and bails without a
-- key -- but llama.cpp does NOT enforce the bearer token (vLLM, which this
-- config used before, did), so a constant is enough and serve.env is no longer
-- read here.
-- Reasoning suppression: Qwen3.8 emits reasoning_content by default and it
-- burns the token budget and clutters the chat pane. The verified knob on this
-- llama.cpp endpoint is `enable_thinking=false`; the vLLM spelling
-- `thinking=false` is silently IGNORED here (re-verified 2026-09-20 against
-- monty:8084 -- see claude_prompt/api.lua).
-- NOTE: *_cmd strings are split on whitespace and exec'd directly (no shell),
-- so shell syntax (${VAR:-x}, pipes, globs) will NOT expand here.
--
-- Option keys follow the plugin's CURRENT schema (popup_window / popup_input /
-- chat.*). The older chat_window / chat_input / top-level welcome_message keys
-- are silently ignored by the plugin, which is why the previous config's
-- titles never showed.

-- The only model this endpoint serves. Referenced wherever a model id has to
-- be sent, so the three request paths (chat, edit, :ChatGPTRun actions) cannot
-- drift apart again.
local ICARUS_MODEL = 'qwen3.8-flash-next'

-- Sampling temperature for the paths that write into a BUFFER (edits and every
-- buffer-mutating :ChatGPTRun action), as opposed to the chat pane, which stays
-- at 0. Sent client-side on purpose: a server-side default only applies to
-- requests that omit the field, and these do not.
local ICARUS_EDIT_TEMPERATURE = 0.2

-- Text rendering of icarus.png: amber wing over the white ICARUS wordmark
-- (the same mark the icarus web-ui header wears). Lines 1-7 are the wing,
-- 8-12 the letters; the split drives the two-tone highlight below.
local ICARUS_WING_LINES = 7
local ICARUS_BANNER = [[
                   ▗▄▖   ▟
             ▄▄▄▖  ▝▜▙  ▟▛
        ▄▄▄▖  ▝▜▙   ▜▙ ▟▛
   ▄▄▄▄▖  ▝▜▙  ▜▙  ▜▙▟▛
       ▝▀▜▙  ▜▙ ▜▙ ▜▛
           ▝▀▜▙▜▙▜▙▛
               ▝▀▜▛
 ██  ██████  █████  ██████  ██  ██ ██████
 ██  ██     ██   ██ ██   ██ ██  ██ ██
 ██  ██     ███████ ██████  ██  ██ ██████
 ██  ██     ██   ██ ██  ██  ██  ██     ██
 ██  ██████ ██   ██ ██   ██ ██████ ██████

        local inference · qwen3.8-flash-next @ monty:8084
]]

later(function()
  add('jackMort/ChatGPT.nvim')

  -- Brand colours are literal, not theme tokens: they are lifted from
  -- icarus.png (gold wing, #eeeeee wordmark) and must read the same on any
  -- colorscheme, exactly like the web-ui plate.
  vim.api.nvim_set_hl(0, 'IcarusWing', { fg = '#d9a520' })
  vim.api.nvim_set_hl(0, 'IcarusWord', { fg = '#eeeeee', bold = true })
  vim.api.nvim_set_hl(0, 'IcarusTag',  { link = 'Comment' })
  -- The plugin paints the whole welcome block with ChatGPTWelcome; make that
  -- the wing colour and overlay the letters afterwards (see apply_banner_hl).
  vim.api.nvim_set_hl(0, 'ChatGPTWelcome', { link = 'IcarusWing' })

  -- $OPENAI_API_KEY BEATS api_key_cmd: loadRequiredConfig (chatgpt/api.lua)
  -- checks the environment first and only falls back to the command when the
  -- variable is unset. llama.cpp ignores the bearer header, so an inherited
  -- cloud key is now harmless -- but hiding it keeps the wire request
  -- byte-identical to what this config intends, and would still be load-bearing
  -- if the endpoint ever went back to an auth-enforcing server. Hide it for the
  -- duration of setup() (api.setup() reads the env synchronously) and restore
  -- it, so :terminal and child jobs keep seeing it.
  local inherited_openai_key = vim.env.OPENAI_API_KEY
  vim.env.OPENAI_API_KEY = nil

  require('chatgpt').setup({
    api_host_cmd = 'echo http://monty:8084',
    api_key_cmd = 'echo local-no-auth',
    yank_register = '+',
    chat = {
      welcome_message = ICARUS_BANNER,
      loading_text = 'icarus is thinking',
      question_sign = '',
      answer_sign = 'ﮧ',
      max_line_length = 120,
      keymaps = {
        close = { '<C-c>', '<Esc>' },
        yank_last = '<C-y>',
        scroll_up = '<C-u>',
        scroll_down = '<C-d>',
        toggle_settings = '<C-o>',
        new_session = '<C-n>',
        cycle_windows = '<Tab>',
      },
    },
    popup_layout = {
      default = 'center',
      center = { width = '80%', height = '80%' },
    },
    popup_window = {
      border = {
        highlight = 'FloatBorder',
        style = 'rounded',
        text = { top = ' ICARUS · qwen3.8-flash-next @ monty:8084 ' }, -- nvim-model:title
      },
      buf_options = { filetype = 'markdown' },
    },
    popup_input = {
      prompt = '  ',
      border = {
        highlight = 'FloatBorder',
        style = 'rounded',
        text = { top_align = 'center', top = ' NORMAL ' },
      },
      submit = '<Enter>',
      submit_n = '<C-Enter>',
      placeholder = 'Ask icarus... (Enter to send)',
    },
    settings_window = {
      border = { style = 'rounded', text = { top = ' Settings ' } },
    },
    openai_params = {
      model = ICARUS_MODEL,
      frequency_penalty = 0,
      presence_penalty = 0,
      max_tokens = 4096,
      temperature = 0,
      top_p = 1,
      n = 1,
      -- Qwen3.8 streams reasoning_content by default; it burns the token
      -- budget and clutters the chat pane. Verified live on monty:8084:
      -- `enable_thinking=false` suppresses it (0 reasoning tokens); the vLLM
      -- spelling `thinking=false` is IGNORED by llama.cpp and leaks reasoning.
      chat_template_kwargs = { enable_thinking = false },
    },
    openai_edit_params = {
      model = ICARUS_MODEL,
      temperature = ICARUS_EDIT_TEMPERATURE,
      top_p = 1,
      n = 1,
      -- `temperature` and `top_p` DO reach the wire: code_edits.lua merges this
      -- whole table into custom_params (tbl_extend "keep"), and Api.edits copies
      -- exactly model/messages/temperature/top_p out of it. `n` is dropped, and
      -- so is this kwarg -- suppression still applies only because Api.edits
      -- routes through Api.chat_completions, which merges openai_params above.
      chat_template_kwargs = { enable_thinking = false },
    },
  })

  vim.env.OPENAI_API_KEY = inherited_openai_key

  -- Follow icarus's LIVE web model (lua/icarus_endpoint.lua). setup() binds
  -- the host and key once, from api_host_cmd/api_key_cmd above -- those are
  -- now only the fallback. Every request path (chat, edits, :ChatGPTRun
  -- actions) funnels through Api.chat_completions or Api.completions and
  -- reads the URL/header fields at call time, so re-point them there and let
  -- the live model id win over openai_params and the per-action ids.
  local Api = require('chatgpt.api')
  local function follow_icarus(custom_params)
    local ep = require('icarus_endpoint').resolve({
      model = ICARUS_MODEL, base = 'http://monty:8084', key = 'local-no-auth',
    })
    Api.COMPLETIONS_URL = ep.base .. '/v1/completions'
    Api.CHAT_COMPLETIONS_URL = ep.base .. '/v1/chat/completions'
    Api.AUTHORIZATION_HEADER = 'Authorization: Bearer ' .. ep.key
    custom_params.model = ep.model
    custom_params.chat_template_kwargs = require('icarus_endpoint').no_thinking
    return custom_params
  end
  local chat_completions, completions = Api.chat_completions, Api.completions
  Api.chat_completions = function(custom_params, ...)
    return chat_completions(follow_icarus(custom_params), ...)
  end
  Api.completions = function(custom_params, ...)
    return completions(follow_icarus(custom_params), ...)
  end

  -- :ChatGPTRun actions carry their OWN model id, hardcoded per action in the
  -- plugin's actions.json ("params": {"model": "gpt-5-mini"}), and
  -- Api.chat_completions merges with vim.tbl_extend("keep", custom, openai) --
  -- so the action's id WINS over openai_params and monty answers
  -- `The model "gpt-5-mini" does not exist.` read_actions() re-reads its files
  -- on every invocation, so wrap the reader rather than fixing up a table once:
  -- that also covers actions added by a future version of the plugin.
  --
  -- The same wrapper pins the edit temperature. Every shipped action is
  -- type="chat", so they all inherit openai_params.temperature (0) rather than
  -- openai_edit_params -- but most of them REWRITE THE BUFFER (strategy replace/
  -- edit/append/prepend/quick_fix) and want the same sampling as an edit. Only
  -- `display`, which just shows output in a window, stays with the chat value.
  local BUFFER_STRATEGIES = {
    replace = true, edit = true, append = true, prepend = true, quick_fix = true,
  }
  local actions = require('chatgpt.flows.actions')
  local read_actions = actions.read_actions
  actions.read_actions = function()
    local defs = read_actions()
    for _, def in pairs(defs) do
      local params = def.opts and def.opts.params
      if params then
        params.model = ICARUS_MODEL
        if BUFFER_STRATEGIES[def.opts.strategy] then
          params.temperature = ICARUS_EDIT_TEMPERATURE
        end
      end
    end
    return defs
  end

  -- Vim-mode indicator ---------------------------------------------------------
  -- The prompt popup is a floating window: it has no statusline, and
  -- 'showmode' is off globally, so insert vs normal was invisible inside it.
  -- Mirror the mode into the input border title, coloured with the same
  -- mini.statusline groups the rest of the editor uses.
  local mode_labels = {
    n = { 'NORMAL',  'MiniStatuslineModeNormal'  },
    i = { 'INSERT',  'MiniStatuslineModeInsert'  },
    v = { 'VISUAL',  'MiniStatuslineModeVisual'  },
    V = { 'V-LINE',  'MiniStatuslineModeVisual'  },
    ['\22'] = { 'V-BLOCK', 'MiniStatuslineModeVisual' },
    R = { 'REPLACE', 'MiniStatuslineModeReplace' },
    c = { 'COMMAND', 'MiniStatuslineModeCommand' },
  }

  local function current_chat()
    local ok, flow = pcall(require, 'chatgpt.flows.chat')
    if not ok or flow.chat == nil or not flow.chat.active then return nil end
    return flow.chat
  end

  local function render_mode()
    local chat = current_chat()
    if chat == nil or chat.chat_input == nil then return end
    local input = chat.chat_input
    if vim.api.nvim_get_current_buf() ~= input.bufnr then return end
    local m = vim.fn.mode():sub(1, 1)
    local label = mode_labels[m] or { 'OTHER', 'MiniStatuslineModeOther' }
    local NuiText = require('nui.text')
    pcall(input.border.set_text, input.border, 'top', NuiText(' ' .. label[1] .. ' ', label[2]), 'center')
  end

  -- Two-tone banner: the plugin already painted every welcome line amber via
  -- ChatGPTWelcome; re-paint the wordmark rows white and the tagline dim.
  local ns = vim.api.nvim_create_namespace('icarus_banner')
  local function apply_banner_hl()
    local chat = current_chat()
    if chat == nil or chat.chat_window == nil then return end
    local buf = chat.chat_window.bufnr
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, ICARUS_WING_LINES + 8, false)
    -- Only touch a fresh session: the first wordmark row is a full block glyph.
    if not (lines[ICARUS_WING_LINES + 1] or ''):find('██', 1, true) then return end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, line in ipairs(lines) do
      local row = i - 1
      if row >= ICARUS_WING_LINES then
        local hl = line:find('██', 1, true) and 'IcarusWord' or 'IcarusTag'
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_col = #line, hl_group = hl, priority = 200 })
      end
    end
  end

  local group = vim.api.nvim_create_augroup('IcarusChatUI', { clear = true })
  vim.api.nvim_create_autocmd({ 'ModeChanged', 'BufEnter' }, {
    group = group,
    callback = function() vim.schedule(render_mode) end,
  })

  -- `:Icarus` is the branded entry point; it opens the chat and paints the
  -- banner once the popup exists. `:ChatGPT*` commands keep working.
  vim.api.nvim_create_user_command('Icarus', function()
    vim.cmd('ChatGPT')
    vim.defer_fn(function()
      apply_banner_hl()
      render_mode()
    end, 30)
  end, { desc = 'Open the Icarus chat (local GLM inference)' })
end)

-- Kill-switch for bisecting UI problems: `nvim --cmd "let g:no_noice = 1"`.
-- noice replaces the message/cmdline UI via vim.ui_attach(ext_messages) and
-- hides the cursor with a blend=100 guicursor while its cmdline is open, so
-- when it breaks on a nightly the symptom is a blank, cursorless window.
if vim.g.no_noice ~= 1 then later(function()
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
end) end

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
