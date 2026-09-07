-- Modal prompt field for <Leader>ap.
--
-- vim.ui.input (rendered by noice) closes the whole field on <Esc>, which
-- makes normal-mode editing impossible. This is a nui Input popup with vim
-- semantics instead:
--   <Esc>   insert -> normal (the field stays open)
--   <C-c>   cancel from either mode
--   <CR>    submit from either mode
-- The border title shows the target model and the current vim mode, coloured
-- with the same MiniStatuslineMode* groups the rest of the editor uses.
local M = {}

local mode_labels = {
  n = { 'NORMAL', 'MiniStatuslineModeNormal' },
  i = { 'INSERT', 'MiniStatuslineModeInsert' },
  v = { 'VISUAL', 'MiniStatuslineModeVisual' },
  V = { 'V-LINE', 'MiniStatuslineModeVisual' },
  ['\22'] = { 'V-BLOCK', 'MiniStatuslineModeVisual' },
  R = { 'REPLACE', 'MiniStatuslineModeReplace' },
  c = { 'COMMAND', 'MiniStatuslineModeCommand' },
}

local function title_line(model_name)
  local NuiLine, NuiText = require('nui.line'), require('nui.text')
  local m = vim.fn.mode():sub(1, 1)
  local label = mode_labels[m] or { 'OTHER', 'MiniStatuslineModeOther' }
  local line = NuiLine()
  line:append(NuiText(' ' .. model_name .. ' ', 'FloatTitle'))
  line:append(NuiText(' ' .. label[1] .. ' ', label[2]))
  return line
end

--- Open the prompt field.
---@param opts { model_name: string, on_submit: fun(value: string), on_cancel: fun()|nil }
function M.open(opts)
  local ok, Input = pcall(require, 'nui.input')
  if not ok then
    -- nui not loaded yet (MiniDeps.later): degrade to the plain field
    vim.ui.input({ prompt = opts.model_name .. ': ' }, function(v)
      if v and v ~= '' then opts.on_submit(v) end
    end)
    return
  end
  local event = require('nui.utils.autocmd').event

  local input
  local done = false
  local function finish(value)
    if done then return end
    done = true
    input:unmount()
    if value and value ~= '' then
      opts.on_submit(value)
    elseif opts.on_cancel then
      opts.on_cancel()
    end
  end

  input = Input({
    relative = 'cursor',
    position = { row = 1, col = 0 },
    size = { width = 60 },
    border = {
      style = 'rounded',
      text = { top = ' ' .. opts.model_name .. ' ', top_align = 'left' },
    },
    win_options = { winhighlight = 'Normal:Normal,FloatBorder:FloatBorder' },
  }, {
    prompt = '❯ ',
    on_submit = function(value) finish(value) end,
    on_close = function() finish(nil) end,
  })

  input:mount()

  -- Submit from normal mode (a prompt buffer's <CR> would otherwise just
  -- re-enter insert mode). Read the line minus the prompt glyph.
  input:map('n', '<CR>', function()
    local line = vim.api.nvim_buf_get_lines(input.bufnr, 0, 1, false)[1] or ''
    finish(line:sub(input._.prompt:length() + 1))
  end, { noremap = true })

  -- Cancel from either mode. <Esc> is deliberately NOT mapped: it falls
  -- through to vim's own insert -> normal transition.
  input:map('n', '<C-c>', function() finish(nil) end, { noremap = true })
  input:map('i', '<C-c>', function() finish(nil) end, { noremap = true })

  -- Mode indicator in the border title
  local function render() pcall(input.border.set_text, input.border, 'top', title_line(opts.model_name), 'left') end
  input:on({ event.ModeChanged, event.BufEnter }, function() vim.schedule(render) end)
  render()
end

return M
