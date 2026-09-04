-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ Keybind cheat sheet                                                      │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- Single source of truth for the "what was that key again?" problem. The
-- table below is plain data; `<leader>uk` renders it in a floating window
-- (scrollable, q to close) and `:CheatSheetWrite` regenerates
-- docs/keybindings.md from the same data so the two never drift.
--
-- Add a bind here when you add it in 20_keymaps.lua / 30_mini.lua /
-- 40_plugins.lua. Keep entries grouped by section, one line each.

local M = {}

-- Sections: { name = string, binds = { { keys, desc }, ... } }
M.binds = {
  {
    name = 'AI completion (minuet, manual trigger)',
    binds = {
      { '<M-.>',  'Request suggestion / cycle next (insert mode)' },
      { '<M-,>',  'Request suggestion / cycle previous (insert mode)' },
      { '<C-l>',  'Accept suggestion (or completion popup item)' },
      { '<M-j>',  'Accept one line of suggestion' },
      { '<M-w>',  'Accept N lines (prompts for N)' },
      { '<C-]>',  'Dismiss suggestion' },
      { '<leader>uc', 'Toggle minuet auto-trigger (buffer)' },
      { '<leader>uC', 'Pick minuet model' },
    },
  },
  {
    name = 'Cheat sheet',
    binds = {
      { '<leader>uk', 'Open this cheat sheet' },
    },
  },
  {
    name = 'Everyday editing',
    binds = {
      { '<Esc>',      'Insert at end of line (normal mode)' },
      { ',',          'Change whole word (normal mode)' },
      { '<F3>',       'Write file' },
      { 'Q',          'Quit (force)' },
      { '<F9>',       'Toggle search highlight' },
      { '[p',         'Paste above (linewise)' },
      { ']p',         'Paste below (linewise)' },
      { 'gK',         'Smart docs: terraform registry / LSP hover' },
    },
  },
  {
    name = 'Buffers & windows',
    binds = {
      { '<S-h>',   'Next buffer' },
      { '<S-l>',   'Previous buffer' },
      { '<F5>',    'Window up' },
      { '<F6>',    'Window right' },
      { '<F10>',   'Window left' },
      { '<F4>',    'Window down' },
      { '<C-Arrow>', 'Resize window (arrows)' },
      { '<leader>ba', 'Alternate buffer' },
      { '<leader>bd', 'Delete buffer' },
      { '<leader>bs', 'Scratch buffer' },
      { '<leader>x',  'Close tab / delete buffer' },
    },
  },
  {
    name = 'Find & explore',
    binds = {
      { '<leader>ff', 'Find files' },
      { '<leader>fg', 'Grep live' },
      { '<leader>fG', 'Grep word under cursor' },
      { '<leader>fb', 'Buffers' },
      { '<leader>fh', 'Help tags' },
      { '<leader>fr', 'Resume last picker' },
      { '<Up>',       'Telescope live grep' },
      { '<leader>e',  'Neo-tree toggle' },
      { '<leader>ed', 'File explorer (mini.files)' },
      { '<leader>fi', 'Emoji / icon picker' },
      { '<leader><leader>f', 'Telescope find files' },
      { '<leader><leader>gr', 'LSP references (telescope)' },
      { '<leader><leader>gd', 'LSP definitions (telescope)' },
    },
  },
  {
    name = 'LSP',
    binds = {
      { '<leader>la', 'Code actions' },
      { '<leader>ld', 'Diagnostic popup' },
      { '<leader>lf', 'Format (conform)' },
      { '<leader>lh', 'Hover' },
      { '<leader>lr', 'Rename' },
      { '<leader>ls', 'Definition' },
      { '<leader>li', 'Implementation' },
      { '<leader>lR', 'References' },
    },
  },
  {
    name = 'Git',
    binds = {
      { '<leader>gs', 'Show at cursor' },
      { '<leader>gd', 'Diff' },
      { '<leader>gD', 'Diff buffer' },
      { '<leader>gc', 'Commit' },
      { '<leader>gC', 'Commit amend' },
      { '<leader>gl', 'Log' },
      { '<leader>gL', 'Log buffer' },
      { '<leader>go', 'Toggle diff overlay' },
    },
  },
  {
    name = 'AI chat (ChatGPT.nvim via local llama.cpp)',
    binds = {
      { '<C-e>', 'Open chat (normal) / explain code (visual)' },
      { '<C-f>', 'Fix bugs (visual selection)' },
      { '<C-t>', 'Add tests (visual selection)' },
    },
  },
  {
    name = 'UI toggles',
    binds = {
      { '<leader>uf', 'Toggle autoformat (global)' },
      { '<leader>uF', 'Toggle autoformat (buffer)' },
      { '<leader>uj', 'Toggle YAML/Jinja2 filetype' },
      { '<leader>mt', 'Toggle minimap' },
      { '<leader>oz', 'Zoom window toggle' },
    },
  },
  {
    name = 'Terminal',
    binds = {
      { '<leader>TT', 'Terminal (horizontal)' },
      { '<leader>Tt', 'Terminal (vertical)' },
    },
  },
  {
    name = 'Neovide only',
    binds = {
      { '<C-=>',  'Zoom in' },
      { '<C-->',  'Zoom out' },
      { '<C-0>',  'Reset zoom' },
      { '<C-S-c>', 'Copy to system clipboard' },
      { '<C-S-v>', 'Paste from system clipboard' },
    },
  },
}

-- Render the binds table as aligned plain text.
local function render()
  local lines = {}
  local width = 0
  for _, section in ipairs(M.binds) do
    table.insert(lines, section.name)
    table.insert(lines, string.rep('─', math.max(#section.name, 20)))
    for _, b in ipairs(section.binds) do
      local line = string.format('  %-14s %s', b[1], b[2])
      width = math.max(width, vim.fn.strdisplaywidth(line))
      table.insert(lines, line)
    end
    table.insert(lines, '')
  end
  return lines, width
end

-- Open the cheat sheet in a floating window. Scrollable, `q` closes.
function M.open()
  local lines, width = render()
  local height = math.min(#lines, vim.o.lines - 6)
  width = math.min(width + 4, vim.o.columns - 6)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' Keybindings  (q to close) ',
    title_pos = 'center',
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, silent = true })
end

-- Regenerate docs/keybindings.md from the same data (keeps docs in sync).
function M.write_markdown()
  local out = { '# Keybindings', '' }
  for _, section in ipairs(M.binds) do
    table.insert(out, '## ' .. section.name)
    table.insert(out, '')
    table.insert(out, '| Keys | Action |')
    table.insert(out, '|---|---|')
    for _, b in ipairs(section.binds) do
      table.insert(out, string.format('| `%s` | %s |', b[1], b[2]))
    end
    table.insert(out, '')
  end
  local path = vim.fn.stdpath('config') .. '/docs/keybindings.md'
  vim.fn.writefile(out, path)
  vim.notify('Wrote ' .. path, vim.log.levels.INFO)
end

vim.api.nvim_create_user_command('CheatSheetWrite', M.write_markdown, {
  desc = 'Regenerate docs/keybindings.md from the cheat sheet data',
})

-- <leader>uk - open cheat sheet (u group = UI/toggle, k = keys)
vim.keymap.set('n', '<leader>uk', M.open, { desc = 'Keybind cheat sheet' })

return M
