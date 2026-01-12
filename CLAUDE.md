# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Neovim configuration called "MiniMax" built primarily around mini.nvim. It uses MiniDeps as the plugin manager.

## Architecture

```
init.lua          - Entry point, bootstraps mini.nvim and MiniDeps, configures LSP servers
plugin/           - Auto-sourced during startup (numbered for load order)
├── 10_options.lua   - Built-in Neovim options, diagnostics config
├── 20_keymaps.lua   - Custom mappings (Leader = Space)
├── 30_mini.lua      - All mini.nvim module configurations
├── 40_plugins.lua   - External plugins (tree-sitter, LSP, conform, etc.)
snippets/         - Global snippet files (JSON format)
after/
├── ftplugin/     - Filetype-specific settings
├── lsp/          - Language server configurations
├── snippets/     - Higher priority snippet files
```

## Key Patterns

**Plugin Loading**: Uses `MiniDeps.now()` for immediate loading and `MiniDeps.later()` for deferred loading. `Config.now_if_args` loads immediately only when Neovim opens with a file argument.

**Global Config Table**: `_G.Config` stores shared configuration (autocommand helper, leader group clues).

**Two-Key Leader Mappings**: First key is semantic group, second is action (e.g., `<Leader>ff` = find files, `<Leader>gs` = git show at cursor).

## LSP Configuration

LSP servers are configured in init.lua using `vim.lsp.enable()` and `vim.lsp.config()`. Currently configured: lua_ls, terraform-ls, bashls, basedpyright.

## Key Dependencies

- mini.nvim (core functionality)
- nvim-treesitter (syntax highlighting, textobjects)
- nvim-lspconfig (LSP configurations)
- conform.nvim (formatting)
- mason.nvim (external tool installation)
- friendly-snippets (snippet collection)
