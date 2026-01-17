-- Auto-trigger file path completion when typing path patterns
-- Detects: ./ ../ / ~/ and triggers <C-x><C-f> automatically

local path_completion_group = vim.api.nvim_create_augroup('path-completion', {})
vim.api.nvim_create_autocmd('TextChangedI', {
  group = path_completion_group,
  callback = function()
    -- Skip if popup menu is already visible
    if vim.fn.pumvisible() == 1 then return end

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before_cursor = line:sub(1, col)

    -- Match path patterns: ./ ../ / ~/ or word/
    if before_cursor:match('[%.~/][%.%w_-]*/?[%w_.-]*$')
      or before_cursor:match('%s[%.~/][%w_.-/]*$')
      or before_cursor:match('^[%.~/][%w_.-/]*$')
      or before_cursor:match('[%w_-]+/[%w_.-]*$') then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<C-x><C-f>', true, false, true), 'n', false)
    end
  end,
})
