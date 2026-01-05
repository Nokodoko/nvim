local o = vim.o
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('yank_group', { clear = true })
local format_group = augroup('Format', { clear = true })

-- BUG: this does not currently work
-- doesn't format on save
autocmd('BufWritePre', {
  group = format_group,
  pattern = { '*.tf', '*.py' },
  callback = function()
    require('conform').format({ async = true, lsp_fallback = true })
  end,
})

-- highlight yanked text
autocmd('TextYankPost', {
  group = yank_group,
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({
      higroup = 'IncSearch',
      timeout = 40,
    })
  end,
})