-- ┌─────────────────────────┐
-- │ Filetype config example │
-- └─────────────────────────┘
--
-- This is an example of a configuration that will apply only to a particular
-- filetype, which is the same as file's basename ('markdown' in this example;
-- which is for '*.md' files).
--
-- It can contain any code which will be usually executed when the file is opened
-- (strictly speaking, on every 'filetype' option value change to target value).
-- Usually it needs to define buffer/window local options and variables.
-- So instead of `vim.o` to set options, use `vim.bo` for buffer-local options and
-- `vim.cmd('setlocal ...')` for window-local options (currently more robust).
--
-- This is also a good place to set buffer-local 'mini.nvim' variables.
-- See `:h mini.nvim-buffer-local-config` and `:h mini.nvim-disabling-recipes`.

-- Enable spelling and wrap for window
vim.cmd('setlocal spell wrap')

-- Glowing markup highlights for markdown ======================================
-- Bold text: bright orange glow
vim.api.nvim_set_hl(0, '@markup.strong.markdown_inline', { fg = '#ff9e64', bold = true })
-- Italic text: bright green glow
vim.api.nvim_set_hl(0, '@markup.italic.markdown_inline', { fg = '#9ece6a', italic = true })
-- Strikethrough
vim.api.nvim_set_hl(0, '@markup.strikethrough.markdown_inline', { fg = '#565f89', strikethrough = true })

-- Headers: vivid colors with bold, each level distinct
vim.api.nvim_set_hl(0, '@markup.heading.1.markdown', { fg = '#ff007c', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.2.markdown', { fg = '#7aa2f7', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.3.markdown', { fg = '#bb9af7', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.4.markdown', { fg = '#7dcfff', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.5.markdown', { fg = '#e0af68', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.6.markdown', { fg = '#9ece6a', bold = true })
-- Generic heading fallback
vim.api.nvim_set_hl(0, '@markup.heading.markdown', { fg = '#ff007c', bold = true })

-- Heading markers (the # symbols)
vim.api.nvim_set_hl(0, '@markup.heading.1.marker.markdown', { fg = '#ff007c', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.2.marker.markdown', { fg = '#7aa2f7', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.3.marker.markdown', { fg = '#bb9af7', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.4.marker.markdown', { fg = '#7dcfff', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.5.marker.markdown', { fg = '#e0af68', bold = true })
vim.api.nvim_set_hl(0, '@markup.heading.6.marker.markdown', { fg = '#9ece6a', bold = true })

-- Code spans (inline `code`)
vim.api.nvim_set_hl(0, '@markup.raw.markdown_inline', { fg = '#73daca', bg = '#1a1b26' })

-- Links
vim.api.nvim_set_hl(0, '@markup.link.markdown_inline', { fg = '#7aa2f7', underline = true })
vim.api.nvim_set_hl(0, '@markup.link.url.markdown_inline', { fg = '#565f89', underline = true })
vim.api.nvim_set_hl(0, '@markup.link.label.markdown_inline', { fg = '#7dcfff', bold = true })

-- Fold with tree-sitter
vim.cmd('setlocal foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()')

-- Disable built-in `gO` mapping in favor of 'mini.basics'
vim.keymap.del('n', 'gO', { buffer = 0 })

-- Set formatprg to prettier so `gq` on visual selections formats markdown
-- (including table alignment). Requires prettier installed via Mason or system.
vim.bo.formatprg = 'prettier --parser markdown'

-- Format current table under cursor using conform.nvim
-- Usage: <Leader>lT in Normal mode while cursor is inside a table
vim.keymap.set('n', '<Leader>lT', function()
  -- Find table boundaries by searching for pipe-delimited lines
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local total_lines = vim.api.nvim_buf_line_count(0)

  -- Check if current line is part of a table (contains pipe character)
  local current = vim.api.nvim_buf_get_lines(0, cursor_line - 1, cursor_line, false)[1]
  if not current:match('|') then
    vim.notify('Cursor is not inside a markdown table', vim.log.levels.WARN)
    return
  end

  -- Search upward for first non-table line
  local start_line = cursor_line
  while start_line > 1 do
    local line = vim.api.nvim_buf_get_lines(0, start_line - 2, start_line - 1, false)[1]
    if not line:match('|') then break end
    start_line = start_line - 1
  end

  -- Search downward for last table line
  local end_line = cursor_line
  while end_line < total_lines do
    local line = vim.api.nvim_buf_get_lines(0, end_line, end_line + 1, false)[1]
    if not line:match('|') then break end
    end_line = end_line + 1
  end

  -- Format only the table range using conform
  require('conform').format({
    range = {
      start = { start_line, 0 },
      ['end'] = { end_line, 0 },
    },
    lsp_fallback = false,
  })
end, { buffer = 0, desc = 'Format table' })

-- Set markdown-specific surrounding in 'mini.surround'
vim.b.minisurround_config = {
  custom_surroundings = {
    -- Markdown link. Common usage:
    -- `saiwL` + [type/paste link] + <CR> - add link
    -- `sdL` - delete link
    -- `srLL` + [type/paste link] + <CR> - replace link
    L = {
      input = { '%[().-()%]%(.-%)' },
      output = function()
        local link = require('mini.surround').user_input('Link: ')
        return { left = '[', right = '](' .. link .. ')' }
      end,
    },
  },
}
