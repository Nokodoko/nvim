# Neovim Troubleshooting Guide

A collection of debugging techniques for diagnosing Neovim configuration issues.

## Checking Autocommands

Verify if an autocommand group exists and is loaded:

```vim
:lua print(vim.inspect(vim.api.nvim_get_autocmds({group='your-group-name'})))
```

If you get `Invalid 'group'` error, the autocommand never loaded.

## Checking for Errors

View error messages from startup or runtime:

```vim
:messages
```

## Checking What Files Are Sourced

See all scripts that Neovim has loaded:

```vim
:scriptnames
```

Look for your config files (e.g., `~/.config/nvim/plugin/*.lua`). If they're missing, something is preventing them from loading.

## Checking Runtimepath

Verify your config directory is in the runtimepath:

```vim
:echo &runtimepath
```

Should include `~/.config/nvim`.

## Checking Plugin Loading

Verify plugins are enabled:

```vim
:echo &loadplugins
```

Should return `1`.

## Verbose Startup Logging

Start Neovim with verbose logging to see exactly what's happening:

```bash
nvim -V10 2>&1 | head -100
```

This shows every file being sourced and can reveal where loading stops.

## Manually Sourcing Files

Test if a specific file works by sourcing it manually:

```vim
:luafile ~/.config/nvim/plugin/your-file.lua
" or
:source ~/.config/nvim/plugin/your-file.lua
```

If it errors with "Can't open file", the file doesn't exist at that path.

## Creating Test Files

Create a simple test file to verify plugin directory loading:

```lua
-- plugin/99_test.lua
vim.notify("TEST: plugin folder is loading", vim.log.levels.INFO)
```

Restart Neovim - if you don't see the notification, plugin/ files aren't loading.

## Checking Neovim Version

Some APIs require specific Neovim versions:

```vim
:version
```

- `vim.lsp.enable()` and `vim.lsp.config()` require Neovim 0.11+

## Git Troubleshooting

### Check Untracked Files

Files might exist locally but not be committed:

```bash
git status
git ls-files plugin/
```

### Check Remote Branches

GitHub default branch might differ from local:

```bash
git ls-remote origin
```

Look for `HEAD` pointing to `main` vs `master`. Push to the correct branch:

```bash
# If remote uses 'main' but you're on 'master':
git push origin master:main
```

### Verify Remote Contents

```bash
gh api repos/OWNER/REPO/contents/plugin --jq '.[].name'
```

## Common Issues

1. **Plugin files not loading**: Check `:scriptnames` - if plugin/ files missing, check for errors in init.lua that stop execution early.

2. **Autocommands inside `later()`**: MiniDeps `later()` defers execution. If something errors before your code, it won't run. Move to separate file.

3. **Git branch mismatch**: GitHub default is often `main`, local might be `master`. Always verify with `git ls-remote origin`.

4. **Environment variables persisting**: After commenting out an export, open a new terminal or run `unset VARIABLE_NAME`.
