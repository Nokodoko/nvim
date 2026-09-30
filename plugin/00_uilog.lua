-- bisect guard: nvim --cmd "let g:skip_plugins = ['00_uilog']" skips this file
if vim.g.skip_plugins and vim.tbl_contains(vim.g.skip_plugins, '00_uilog') then return end
-- ┌──────────────────────────────────────────────────────────────────────┐
-- │ UI event logger (temporary, for the blank-window investigation)       │
-- └──────────────────────────────────────────────────────────────────────┘
--
-- Appends one line per UI-relevant event to $NVIM_UILOG (default
-- /tmp/nvim-ui.log) so a second party can `tail -f` it while the editor is
-- used. Also records the RPC socket so the live instance can be probed with
-- `nvim --server <sock> --remote-expr`. Every 2 s it snapshots what decides
-- whether the window is visible: mode, guicursor, every window (floats with
-- blend/zindex/geometry), the Normal/Cursor highlights, and the text of the
-- screen row under the cursor -- so "grid has text" vs "screen shows none"
-- can be told apart from the log alone.
--
-- Disable with `nvim --cmd "let g:uilog = 0"`. Remove this file when done.

if vim.g.uilog == 0 then return end

local path = vim.env.NVIM_UILOG or '/tmp/nvim-ui.log'
local t0 = vim.uv.hrtime()

local function log(kind, msg)
  local f = io.open(path, 'a')
  if not f then return end
  f:write(string.format('%s +%7.3fs [%d] %-12s %s\n',
    os.date('%H:%M:%S'), (vim.uv.hrtime() - t0) / 1e9, vim.fn.getpid(), kind, msg or ''))
  f:close()
end

local function hl(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok then return '?' end
  local parts = {}
  for k, v in pairs(h) do
    if type(v) ~= 'table' then parts[#parts + 1] = k .. '=' .. (type(v) == 'number' and string.format('#%06x', v) or tostring(v)) end
  end
  table.sort(parts)
  return '{' .. table.concat(parts, ',') .. '}'
end

local function wins()
  local out = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local c = vim.api.nvim_win_get_config(w)
    local b = vim.api.nvim_win_get_buf(w)
    local pos = vim.api.nvim_win_get_position(w)
    out[#out + 1] = string.format('w%d[%s ft=%s %dx%d@%d,%d blend=%d z=%s hide=%s winhl=%q]',
      w, c.relative ~= '' and 'FLOAT:' .. c.relative or 'split', vim.bo[b].filetype,
      vim.api.nvim_win_get_width(w), vim.api.nvim_win_get_height(w), pos[1], pos[2],
      vim.wo[w].winblend, tostring(c.zindex), tostring(c.hide), vim.wo[w].winhighlight)
  end
  return table.concat(out, ' ')
end

local function screen_row(row)
  local cells = {}
  for c = 1, math.min(vim.o.columns, 80) do cells[#cells + 1] = vim.fn.screenstring(row, c) end
  return (table.concat(cells):gsub('%s+$', ''))
end

local function snapshot(why)
  local ok, err = pcall(function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local srow = vim.fn.screenpos(0, cur[1], cur[2] + 1).row
    log('snapshot', string.format('%s mode=%s buf=%d ft=%s guicursor=%q lazyredraw=%s cmdheight=%d lines=%d cols=%d',
      why, vim.fn.mode(true), vim.api.nvim_get_current_buf(), vim.bo.filetype, vim.o.guicursor,
      tostring(vim.o.lazyredraw), vim.o.cmdheight, vim.o.lines, vim.o.columns))
    log('snapshot', 'wins ' .. wins())
    log('snapshot', 'hl Normal=' .. hl('Normal') .. ' Cursor=' .. hl('Cursor') .. ' CursorLine=' .. hl('CursorLine') .. ' NormalFloat=' .. hl('NormalFloat'))
    log('snapshot', string.format('cursor line %d col %d -> screen row %d: %q', cur[1], cur[2], srow, screen_row(srow)))
  end)
  if not ok then log('snapshot', 'ERROR ' .. tostring(err)) end
end

log('start', string.format('nvim %s argv=%s server=%s cwd=%s TERM=%s', tostring(vim.version()), vim.inspect(vim.v.argv), vim.v.servername, vim.fn.getcwd(), vim.env.TERM or ''))

local group = vim.api.nvim_create_augroup('uilog', { clear = true })
local function on(events, fn, pattern)
  vim.api.nvim_create_autocmd(events, { group = group, pattern = pattern, callback = fn })
end

on({ 'VimEnter', 'UIEnter', 'BufEnter', 'BufWinEnter', 'BufNew', 'BufReadPost', 'FileType', 'ColorScheme',
  'WinNew', 'WinClosed', 'WinEnter', 'WinLeave', 'InsertEnter', 'InsertLeave', 'CmdlineEnter', 'CmdlineLeave',
  'TextChanged', 'TextChangedI', 'CompleteDone', 'VimResized', 'FocusGained', 'FocusLost', 'TermOpen', 'User' },
  function(ev)
    log(ev.event, string.format('buf=%d file=%s match=%s', ev.buf or -1, ev.file or '', ev.match or ''))
    if ev.event == 'WinNew' or ev.event == 'WinClosed' or ev.event == 'VimEnter' or ev.event == 'ColorScheme' then
      snapshot(ev.event)
    end
  end)

on('ModeChanged', function(ev) log('ModeChanged', ev.match) end)

on('OptionSet', function(ev)
  log('OptionSet', string.format('%s: %q -> %q (%s)', ev.match, tostring(vim.v.option_old), tostring(vim.v.option_new), vim.v.option_type))
end, { 'guicursor', 'winblend', 'winhighlight', 'conceallevel', 'concealcursor', 'lazyredraw', 'cmdheight',
  'laststatus', 'termguicolors', 'background', 'winbar', 'statusline', 'foldenable', 'cursorline', 'pumblend' })

-- vim.notify / errors: everything a plugin reports goes through here.
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  log('notify', string.format('level=%s %s', tostring(level), tostring(msg):gsub('\n', ' | ')))
  return orig_notify(msg, level, opts)
end

-- ui_attach: which plugin takes over which UI extension (noice does this).
local orig_ui_attach = vim.ui_attach
vim.ui_attach = function(ns, opts, cb)
  log('ui_attach', string.format('ns=%d opts=%s from %s', ns, vim.inspect(opts):gsub('%s+', ' '), debug.traceback('', 2):gsub('\n', ' <- '):sub(1, 400)))
  return orig_ui_attach(ns, opts, cb)
end
local orig_ui_detach = vim.ui_detach
vim.ui_detach = function(ns)
  log('ui_detach', 'ns=' .. tostring(ns))
  return orig_ui_detach(ns)
end

-- Periodic snapshot: the state that decides visibility, every 2 s.
local timer = vim.uv.new_timer()
timer:start(2000, 2000, vim.schedule_wrap(function() snapshot('tick') end))

vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
  timer:stop()
  log('exit', 'VimLeavePre')
end })
