-- Claude prompt plugin registration
-- Sets up user commands and keymaps for Claude AI integration

local claude = require('claude_prompt')

-- Create user commands
vim.api.nvim_create_user_command('ClaudePrompt', function()
  claude.prompt()
end, {
  desc = 'Prompt Claude with buffer context',
})

vim.api.nvim_create_user_command('ClaudePromptVisual', function()
  claude.prompt_visual()
end, {
  range = true,
  desc = 'Prompt Claude with visual selection',
})

vim.api.nvim_create_user_command('ClaudeCancel', function()
  claude.cancel()
  vim.notify('Claude: Request cancelled', vim.log.levels.INFO)
end, {
  desc = 'Cancel in-flight Claude request',
})

-- Add leader group clue for AI commands
table.insert(_G.Config.leader_group_clues, { mode = 'n', keys = '<Leader>a', desc = '+AI' })
table.insert(_G.Config.leader_group_clues, { mode = 'x', keys = '<Leader>a', desc = '+AI' })

-- Keymap helpers
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- Normal mode: prompt with buffer context
nmap_leader('ap', '<Cmd>ClaudePrompt<CR>', 'Prompt Claude')

-- Visual mode: prompt with selection
xmap_leader('ap', ':<C-u>ClaudePromptVisual<CR>', 'Prompt with selection')

-- Cancel request (normal mode only)
nmap_leader('ac', '<Cmd>ClaudeCancel<CR>', 'Cancel request')
