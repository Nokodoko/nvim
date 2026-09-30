-- bisect guard: nvim --cmd "let g:skip_plugins = ['chunked']" skips this file
if vim.g.skip_plugins and vim.tbl_contains(vim.g.skip_plugins, 'chunked') then return end
-- Chunk visualizer commands and keymaps
--
-- Wires lua/chunked.lua (the attention-aware chunk visualizer) into the
-- editor. The visualization itself is AUTO-ENABLED by chunked.setup() for
-- every buffer of a measured filetype (markdown / promptmd / xml / html) --
-- this editor's buffers are model-driven prompts, so the chunk view is meant
-- to be ambient. The commands below exist to turn it off, force a re-analyze,
-- or script it.
--
-- `<Leader>c` group:
--   <Leader>ct  toggle chunk visualization for the current buffer
--   <Leader>ca  force a re-analyze (re-chunk now)
--   <Leader>co  turn chunk visualization off

local chunked = require('chunked')

chunked.setup()

local function enable()
  local _, summary = chunked.enable()
  local extra = {}
  if summary.oversized > 0 then extra[#extra + 1] = string.format('%d oversized', summary.oversized) end
  if summary.hazards > 0 then extra[#extra + 1] = string.format('%d clip hazard%s', summary.hazards, summary.hazards > 1 and 's' or '') end
  local msg = string.format('Chunked: %d chunks · ~%d tokens', summary.chunks, math.floor(summary.tokens))
  if #extra > 0 then msg = msg .. ' · ' .. table.concat(extra, ', ') end
  vim.notify(msg, summary.hazards > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
end


vim.api.nvim_create_user_command('Chunk', function(opts)
  -- :Chunk on/off/analyze make the command scriptable and self-documenting;
  -- a bare :Chunk toggles.
  local sub = opts.args and opts.args ~= '' and opts.args or 'toggle'
  if sub == 'on' then
    enable()
  elseif sub == 'off' then
    chunked.disable()
    vim.notify('Chunked: off', vim.log.levels.INFO)
  else
    if vim.b.chunked_enabled then
      chunked.disable()
      vim.notify('Chunked: off', vim.log.levels.INFO)
    else
      enable()
    end
  end
end, {
  desc = 'Visualize prompt chunk boundaries (on/off/toggle)',
  nargs = '?',
  complete = function(arg_lead)
    return vim.tbl_filter(function(s) return s:find('^' .. vim.pesc(arg_lead)) end, { 'on', 'off', 'toggle' })
  end,
})

-- Leader group clue (mini.clue reads _G.Config.leader_group_clues, populated
-- in plugin/20_keymaps.lua, which loads before this file by name order).
table.insert(_G.Config.leader_group_clues, { mode = 'n', keys = '<Leader>c', desc = '+Chunk' })

vim.keymap.set('n', '<Leader>ct', '<Cmd>Chunk<CR>', { desc = 'Toggle chunk view' })
vim.keymap.set('n', '<Leader>ca', '<Cmd>Chunk on<CR>', { desc = 'Analyze chunks now' })
vim.keymap.set('n', '<Leader>co', '<Cmd>Chunk off<CR>', { desc = 'Chunk view off' })
