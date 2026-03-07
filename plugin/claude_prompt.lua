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
  desc = 'Prompt Claude with visual selection',
})

vim.api.nvim_create_user_command('ClaudeCancel', function()
  claude.cancel()
  vim.notify('Claude: Request cancelled', vim.log.levels.INFO)
end, {
  desc = 'Cancel in-flight Claude request',
})

vim.api.nvim_create_user_command('ClaudeModel', function()
  local api = require('claude_prompt.api')
  vim.ui.select(
    vim.tbl_map(function(m) return m.name end, api.models),
    { prompt = 'Select model: ' },
    function(choice, idx)
      if idx then
        api.set_model(api.models[idx].id)
        vim.notify('Model set to: ' .. api.models[idx].name, vim.log.levels.INFO)
      end
    end
  )
end, {
  desc = 'Select Claude model',
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

-- Select model (normal mode only)
nmap_leader('am', '<Cmd>ClaudeModel<CR>', 'Select model')

-- Insert last Claude Code response into buffer
vim.api.nvim_create_user_command('ClaudeInsertResponse', function()
  claude.insert_last_response()
end, {
  desc = 'Insert last Claude Code response into buffer',
})

nmap_leader('ai', '<Cmd>ClaudeInsertResponse<CR>', 'Insert last response')

-- Select from recent Claude responses via telescope
vim.api.nvim_create_user_command('ClaudeSelectResponse', function()
  claude.select_response()
end, {
  desc = 'Select a Claude response from history',
})

nmap_leader('as', '<Cmd>ClaudeSelectResponse<CR>', 'Select response history')

-- Insert mode: trigger prompt with Ctrl+A
vim.keymap.set('i', '<C-a>', function()
  vim.cmd('stopinsert')
  vim.schedule(function() require('claude_prompt').prompt() end)
end, { desc = 'Prompt Claude' })
