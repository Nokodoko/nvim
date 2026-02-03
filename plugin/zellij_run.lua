-- Zellij floating pane runner plugin
-- Setup commands and keymaps for zellij_run module

local M = require('zellij_run')

-- Create the command that intercepts :!<interpreter>
-- Usage: Select text in visual mode, then :!bash (or :!python, etc.)
vim.api.nvim_create_user_command('ZellijRun', function(opts)
  M.run_in_zellij(opts.args)
end, {
  nargs = 1,
  range = true,
  desc = 'Run visual selection in Zellij floating pane',
})

-- Override visual mode ! behavior to use ZellijRun with bash
-- Use vim.schedule to ensure this runs after all plugins are loaded
vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    vim.keymap.set('v', '!', ':<C-u>ZellijRun zsh<CR>', { desc = 'Run in Zellij floating pane' })
  end,
})
