-- icarus_chat: the <C-e> chat surface, backed by `icarus --mode rpc`.
--
-- WHY NOT THE OLD CHAT. <C-e> used to open ChatGPT.nvim pointed at a bare
-- llama.cpp endpoint. That is a completion API with a chat history bolted on:
-- it has no tools, so it cannot read ob1, cannot run bash, and has no skills.
-- This module talks to icarus's own pi-rpc adapter instead, whose backend
-- builds the agent with cli.BuildAgent and runs agent.Loop.Run -- the same
-- path the REPL and the web UI use. Verified live against the installed
-- binary: a session opened here ran the bash tool and called the ob1 MCP
-- ob_status tool, which returned real item counts.
--
-- THE FOUR REQUIREMENTS, AND WHERE EACH LIVES:
--   1. read from ob1      -- free: the icarus session carries the ob1 MCP tools.
--   2. act on a buffer    -- here, and only here. icarus cannot see the editor
--                           (diff/apply and context/inject answer -32601 on
--                           this build), so context is prepended to the prompt
--                           text and replies are inserted by an explicit
--                           keymap, <Leader>ii.
--   3. bash tool          -- free, same as 1.
--   4. skills             -- icarus discovers <root>/.icarus/skills and
--                           ~/.config/icarus/skillsets itself; the picker here
--                           offers `/name` for those.
--
-- BUFFER LAYOUT (a plain modifiable buffer, so it yanks, greps and diffs
-- normally):
--
--    ICARUS · session 17ab… · llamacpp-monty-qwen0/qwen3.8-flash-next · ready
--
--   ▸ you
--   <user text>
--
--   ▸ icarus
--   <reply text>
--
--   <input line; <CR> submits, an empty <CR> is a newline>
--
-- Entry identity never depends on the text: each chat's `entries` records
-- { kind, marker, lastline, text } and is rebuilt from the markers after every
-- mutation, so manual edits and `dd` cannot reassign a reply.
--
-- STATE LIVES HERE, NOT IN b:. A session holds functions and libuv handles,
-- and buffer variables must be msgpack-convertible -- assigning one with
-- `vim.b[buf].x = sess` dies with "Cannot convert given Lua type". So `chats`
-- below is the single owner of anything non-plain, and b: keeps only the
-- `icarus_chat` marker flag that M.win() scans for.

local M = {}

local rpc = require('icarus_rpc')

M.opts = {
  -- Where the chat window opens: 'right' | 'left' | 'bottom' | 'float'.
  position = 'right',
  width = 80,
  height = 0.4,
  -- Cap on the editor context prepended to a prompt (bytes).
  context_max_bytes = 24000,
  -- Extra skills to offer in the picker: { name = ..., path = ... } or a path.
  extra_skills = {},
}

local YOU = '▸ you'
local REPLY = '▸ icarus'

-- bufnr -> { rpc, win, target_win, context_buf, status, session_id, entries,
--            stream, pending_context }
local chats = {}

local function st(buf)
  return chats[buf]
end

--- The chat window/buffer in the CURRENT tab (tab-scoped on purpose: a chat
--- per tab matches how the rest of this config behaves).
function M.win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local ok, b = pcall(vim.api.nvim_win_get_buf, w)
    if ok and b and chats[b] then return w, b end
  end
  return nil, nil
end

-- ------------------------------------------------------------------ entries

--- Rebuild the entry index from the marker lines.
local function rebuild_entries(buf)
  local s = st(buf)
  if not s or not vim.api.nvim_buf_is_valid(buf) then return {} end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local entries = {}
  local cur
  for i, line in ipairs(lines) do
    -- Byte-exact marker match. `▸` is 3 bytes in UTF-8, so prefix arithmetic on
    -- these constants is a trap; compare whole lines instead.
    if i > 1 and (line == YOU or line == REPLY) then
      local kind = (line == YOU and 'user') or 'reply'
      cur = { kind = kind, marker = i, lastline = i, text = '' }
      entries[#entries + 1] = cur
    elseif cur then
      cur.lastline = i
    end
  end
  for _, e in ipairs(entries) do
    local body = vim.api.nvim_buf_get_lines(buf, e.marker, e.lastline, false)
    while #body > 0 and body[#body] == '' do table.remove(body) end
    e.text = table.concat(body, '\n')
  end
  s.entries = entries
  return entries
end

--- The entry containing buffer line `lnum` (1-based), or nil.
function M.entry_at(buf, lnum)
  local s = st(buf)
  if not s then return nil end
  for _, e in ipairs(s.entries or {}) do
    if lnum >= e.marker and lnum <= e.lastline then return e end
  end
  return nil
end

-- ------------------------------------------------------------------ header

local function set_status(buf, status, detail)
  local s = st(buf)
  if not s or not vim.api.nvim_buf_is_valid(buf) then return end
  s.status = status
  local ep = require('icarus_endpoint').resolve({ model = '?', base = '', key = '' })
  local sid = (s.session_id or ''):sub(1, 8)
  local glyph = status == 'streaming' and '' or (status == 'error' and '' or '')
  local tail = detail or (status == 'streaming' and 'thinking…' or 'ready')
  local head = string.format('%s ICARUS · session %s · %s/%s · %s',
    glyph, sid == '' and '(new)' or sid, ep.provider or '?', ep.model, tail)
  if vim.api.nvim_buf_line_count(buf) == 0 then
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { head, '' })
  else
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, { head })
  end
end

local function append_lines(buf, lines)
  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, last, last, false, lines)
  return last + 1, last + #lines
end

-- ------------------------------------------------------------------ stream

--- Paint one streamed delta into the open reply block.
---
--- Invariant: s.stream.lnum is the line the next delta appends to. A delta may
--- itself contain newlines, so line lnum is replaced by (line .. first piece)
--- followed by the remaining pieces, and lnum advances to the last line
--- written.
local function render_delta(buf, delta)
  local s = st(buf)
  if not s or not s.stream or not vim.api.nvim_buf_is_valid(buf) then return end
  local at = s.stream.lnum
  local pieces = vim.split(delta, '\n', { plain = true })
  local cur = vim.api.nvim_buf_get_lines(buf, at - 1, at, false)[1] or ''
  local replacement = { cur .. pieces[1] }
  for i = 2, #pieces do replacement[#replacement + 1] = pieces[i] end
  vim.api.nvim_buf_set_lines(buf, at - 1, at, false, replacement)
  s.stream.lnum = at + #pieces - 1
  s.stream.painted = true
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    pcall(vim.api.nvim_win_set_cursor, s.win, { s.stream.lnum, 0 })
  end
end

-- ------------------------------------------------------------------ submit

--- Send `text` as a prompt on this chat's session.
function M.submit(buf, text)
  local s = st(buf)
  if not s or not vim.api.nvim_buf_is_valid(buf) then return end
  if s.status == 'streaming' then
    vim.notify('icarus is still answering; <C-c> in the chat aborts', vim.log.levels.WARN)
    return
  end
  if not s.rpc or s.rpc.closed then
    vim.notify('icarus session is closed; reopen with :IcarusChat', vim.log.levels.ERROR)
    return
  end

  local ctx = s.pending_context
  s.pending_context = nil
  local prompt = (ctx and ctx ~= '') and (ctx .. '\n\n' .. text) or text

  append_lines(buf, { YOU, text, '' })
  local rfirst = append_lines(buf, { REPLY, '' })
  s.stream = { lnum = rfirst + 1, painted = false }
  rebuild_entries(buf)
  set_status(buf, 'streaming')

  if s.win and vim.api.nvim_win_is_valid(s.win) then
    pcall(vim.api.nvim_win_set_cursor, s.win, { rfirst + 1, 0 })
  end

  s.rpc:prompt(prompt, {
    on_update = function(kind, res)
      if kind == 'delta' then
        render_delta(buf, res.delta)
      elseif kind == 'start' and res.session_id then
        s.session_id = res.session_id
      end
    end,
    on_done = function(res, err)
      local stream = s.stream
      s.stream = nil
      s.session_id = s.rpc.session_id or s.session_id
      if not vim.api.nvim_buf_is_valid(buf) then return end
      if err then
        set_status(buf, 'error', err)
        append_lines(buf, { '⚠ ' .. err, '' })
      elseif stream and not stream.painted and res and res.text and res.text ~= '' then
        -- Nothing ever streamed (a non-streaming-shaped reply): paint the
        -- authoritative text into the reply block left empty.
        vim.api.nvim_buf_set_lines(buf, stream.lnum - 1, stream.lnum, false,
          vim.split(res.text, '\n', { plain = true }))
        set_status(buf, 'idle', res.stop_reason or 'done')
      else
        set_status(buf, 'idle', res and res.stop_reason or 'done')
      end
      rebuild_entries(buf)
    end,
  })
end

-- ------------------------------------------------------------------ context

--- Build a fenced context block from a buffer range.
function M.context_from(buf, from, to)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then name = '[unnamed ' .. buf .. ']' end
  local rel = vim.fn.fnamemodify(name, ':~:.')
  local ft = vim.bo[buf].filetype or ''
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, from, to, false), '\n')
  if #text > M.opts.context_max_bytes then
    text = text:sub(1, M.opts.context_max_bytes)
      .. '\n… [truncated by icarus_chat.context_max_bytes]'
  end
  return string.format(
    'Context from the editor (buffer %s, filetype %s):\n```%s\n%s\n```', rel, ft, ft, text), rel
end

-- ------------------------------------------------------------------ skills

--- Skills icarus can see. Its registry (internal/skills/loader.go) reads
--- <project>/.icarus/skills, $ICARUS_SKILLS_DIR and ~/.config/icarus/skillsets,
--- each holding <name>/skill.md; those need no flag. `extra` entries come from
--- M.opts.extra_skills.
function M.list_skills()
  local found, seen = {}, {}
  local roots = {
    { vim.fn.expand('.icarus/skills'), 'project' },
    { vim.fn.expand('~/.config/icarus/skillsets'), 'user' },
  }
  for _, r in ipairs(roots) do
    if vim.fn.isdirectory(r[1]) == 1 then
      for _, d in ipairs(vim.fn.glob(r[1] .. '/*', false, true)) do
        local f = d .. '/skill.md'
        if vim.fn.filereadable(f) == 1 then
          local name = vim.fn.fnamemodify(d, ':t')
          if not seen[name] then
            seen[name] = true
            found[#found + 1] = { name = name, path = f, source = r[2] }
          end
        end
      end
    end
  end
  for _, sk in ipairs(M.opts.extra_skills) do
    local p = vim.fn.expand(type(sk) == 'string' and sk or sk.path)
    if vim.fn.filereadable(p) == 1 then
      local name = (type(sk) == 'table' and sk.name) or vim.fn.fnamemodify(p, ':t:r')
      if not seen[name] then
        seen[name] = true
        found[#found + 1] = { name = name, path = p, source = 'extra' }
      end
    end
  end
  table.sort(found, function(a, b) return a.name < b.name end)
  return found
end

--- Pick a skill and put its invocation on the input line.
function M.pick_skill()
  local _, buf = M.win()
  if not buf then
    vim.notify('open a chat first (:IcarusChat)', vim.log.levels.WARN)
    return
  end
  local skills = M.list_skills()
  if #skills == 0 then
    vim.notify('no skills in .icarus/skills or ~/.config/icarus/skillsets', vim.log.levels.WARN)
    return
  end
  vim.ui.select(skills, {
    prompt = 'icarus skill:',
    format_item = function(sk) return string.format('/%s  [%s]', sk.name, sk.source) end,
  }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      -- A discovered skill is invoked as prompt text: icarus expands
      -- `/name args` into the turn body itself.
      M.insert_input(buf, '/' .. choice.name .. ' ')
    end)
  end)
end

--- Put `text` on the input line (end of buffer) and start inserting.
function M.insert_input(buf, text)
  local s = st(buf)
  if not s or not vim.api.nvim_buf_is_valid(buf) then return end
  local last = vim.api.nvim_buf_line_count(buf)
  local cur = vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] or ''
  if cur ~= '' then
    vim.api.nvim_buf_set_lines(buf, last, last, false, { '' })
    last = last + 1
  end
  if text and text ~= '' then
    vim.api.nvim_buf_set_lines(buf, last - 1, last, false, { text })
  end
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    pcall(vim.api.nvim_set_current_win, s.win)
    pcall(vim.api.nvim_win_set_cursor, s.win, { last, text and #text or 0 })
  end
  if vim.api.nvim_get_mode().mode ~= 'i' then
    vim.cmd('startinsert!')
  end
end

-- ------------------------------------------------------------------ actions

--- The window replies go into: the one the chat was opened from, else the
--- first window with a real file that is not the chat.
local function target_win(buf)
  local s = st(buf)
  if not s then return nil end
  if s.target_win and vim.api.nvim_win_is_valid(s.target_win) then return s.target_win end
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if w ~= s.win and not chats[b]
      and vim.bo[b].buftype == '' and vim.api.nvim_buf_get_name(b) ~= '' then
      return w
    end
  end
  return nil
end

--- Insert the reply under the cursor into the target buffer.
function M.insert_to_target(buf)
  local s = st(buf)
  if not s then return end
  local w = target_win(buf)
  if not w then
    vim.notify('no target buffer to insert into', vim.log.levels.WARN)
    return
  end
  local chat_lnum = s.win and vim.api.nvim_win_is_valid(s.win)
    and vim.api.nvim_win_get_cursor(s.win)[1] or nil
  if not chat_lnum then
    vim.notify('chat window is gone', vim.log.levels.WARN)
    return
  end
  local entry = M.entry_at(buf, chat_lnum)
  if not entry then
    vim.notify('cursor is not on a chat entry', vim.log.levels.WARN)
    return
  end
  if entry.kind ~= 'reply' then
    vim.notify('cursor is on a ' .. entry.kind .. ' entry, not an icarus reply', vim.log.levels.WARN)
    return
  end
  if entry.text == '' then
    vim.notify('that reply is empty', vim.log.levels.WARN)
    return
  end
  local tbuf = vim.api.nvim_win_get_buf(w)
  local tlnum = vim.api.nvim_win_get_cursor(w)[1]
  local lines = vim.split(entry.text, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(tbuf, tlnum, tlnum, false, lines)
  vim.notify(string.format('inserted %d line(s) of icarus reply', #lines), vim.log.levels.INFO)
end

--- Send the current buffer (or the visual selection) as context.
--- @param prompt_text string  text to append after the context
--- @param from_visual boolean restrict the context to '<,'>
function M.send_context(prompt_text, from_visual)
  local cur = vim.api.nvim_get_current_buf()
  local _, chat = M.win()
  if chat and cur == chat then
    local src = st(chat).context_buf
    if not src or not vim.api.nvim_buf_is_valid(src) then
      vim.notify('cannot take context from the chat window itself', vim.log.levels.WARN)
      return
    end
    cur = src
  end

  local from, to = 0, -1
  if from_visual then
    local a, b = vim.fn.getpos("'<"), vim.fn.getpos("'>")
    from, to = a[2] - 1, b[2]
  end

  local ctx, rel = M.context_from(cur, from, to)
  if not chat then chat = M.open() end
  st(chat).pending_context = ctx
  local q = (prompt_text and prompt_text ~= '') and prompt_text
    or ('What do you notice about ' .. rel .. '?')
  M.insert_input(chat, q)
end

-- ------------------------------------------------------------------ open

function M.open(opts)
  opts = opts or {}
  local existing_win, existing_buf = M.win()
  if existing_win and not opts.new then
    vim.api.nvim_set_current_win(existing_win)
    return existing_buf
  end

  local origin_win, origin_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()

  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].swapfile = false
  vim.bo[buf].buftype = ''
  -- The only thing kept in b:: a cheap marker. Everything else lives in `chats`
  -- because buffer variables must be msgpack-convertible.
  vim.b[buf].icarus_chat = true

  local pos = opts.position or M.opts.position
  local win
  if pos == 'float' then
    local w = math.min(M.opts.width, vim.o.columns - 4)
    local h = math.floor(vim.o.lines * M.opts.height)
    win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor', width = w, height = h,
      row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2),
      style = 'minimal', border = 'rounded',
      title = ' ICARUS · rpc ', title_pos = 'center',
    })
  else
    -- 0.13 form: split takes a STRING ('right'|'left'|'below'|'above'); the
    -- table form errors with "Invalid 'split': Expected Lua string".
    local side = ({ right = 'right', left = 'left', bottom = 'below', top = 'above' })[pos] or 'right'
    win = vim.api.nvim_open_win(buf, true, { split = side })
    if side == 'right' or side == 'left' then
      vim.api.nvim_win_set_width(win, math.min(M.opts.width, vim.o.columns - 20))
    else
      vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * M.opts.height))
    end
  end

  -- wrap/linebreak are WINDOW-local: assigning them through vim.bo errors with
  -- "'buf' cannot be passed for window-local option 'wrap'".
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].breakindent = true

  local self = {
    win = win,
    target_win = (vim.api.nvim_win_is_valid(origin_win) and origin_win ~= win) and origin_win or nil,
    context_buf = origin_buf,
    status = 'idle',
    entries = {},
    stream = nil,
    pending_context = nil,
    session_id = nil,
  }
  chats[buf] = self

  self.rpc = rpc.open({
    on_exit = function(code, stderr)
      if not vim.api.nvim_buf_is_valid(buf) then return end
      set_status(buf, 'error', 'exited ' .. tostring(code))
      local extra = { '', '⚠ icarus exited (' .. tostring(code) .. ')' }
      if stderr and stderr ~= '' then
        extra[#extra + 1] = '-- stderr (tail) --'
        for _, l in ipairs(vim.split(stderr, '\n')) do extra[#extra + 1] = l end
      end
      append_lines(buf, extra)
    end,
  })

  set_status(buf, 'idle')

  vim.keymap.set('i', '<CR>', function() M.submit_from_insert(buf) end,
    { buffer = buf, desc = 'icarus: send prompt' })
  vim.keymap.set({ 'n', 'i' }, '<C-c>', function() M.abort(buf) end,
    { buffer = buf, desc = 'icarus: abort' })
  vim.keymap.set('n', '<Leader>ii', function() M.insert_to_target(buf) end,
    { buffer = buf, desc = 'icarus: insert reply into buffer' })
  vim.keymap.set('n', '<Leader>is', function() M.pick_skill() end,
    { buffer = buf, desc = 'icarus: pick skill' })
  vim.keymap.set('n', '<Leader>iq', function() M.close(buf) end,
    { buffer = buf, desc = 'icarus: close chat' })

  local group = vim.api.nvim_create_augroup('IcarusChat' .. buf, { clear = true })
  -- Keep the entry index honest under manual edits.
  vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
    group = group, buffer = buf,
    callback = function() rebuild_entries(buf) end,
  })
  -- The child dies with the BUFFER, not the window: closing the split hides the
  -- buffer, and the session must survive that so reopening it keeps context.
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group, buffer = buf, once = true,
    callback = function()
      if self.rpc then self.rpc:close() end
      self.rpc = nil
      chats[buf] = nil
    end,
  })

  vim.api.nvim_set_hl(0, 'IcarusYou', { link = 'Function', default = true })
  vim.api.nvim_set_hl(0, 'IcarusReply', { link = 'Comment', default = true })
  vim.api.nvim_set_hl(0, 'IcarusHeader', { link = 'Directory', default = true })

  -- Fail fast: a broken binary is reported now, not on the first prompt.
  self.rpc:ping(function(res, err)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if err then
      set_status(buf, 'error', 'ping: ' .. err)
      vim.notify('icarus chat: ' .. err, vim.log.levels.ERROR)
    else
      set_status(buf, 'idle')
    end
  end)

  M.insert_input(buf, '')
  return buf
end

--- Insert-mode <CR>: submit the line under the cursor. An empty line is just a
--- newline, so multi-line drafting works.
function M.submit_from_insert(buf)
  local s = st(buf)
  if not s then return end
  local win = s.win
  local lnum = vim.api.nvim_win_get_cursor(win or 0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = lines[lnum] or ''
  if vim.trim(text) == '' then
    vim.api.nvim_buf_set_lines(buf, lnum, lnum, false, { '' })
    pcall(vim.api.nvim_win_set_cursor, win or 0, { lnum + 1, 0 })
    return
  end
  -- Remove the input line; submit() re-echoes it as a user entry.
  vim.api.nvim_buf_set_lines(buf, lnum - 1, lnum, false, {})
  M.submit(buf, text)
end

function M.abort(buf)
  local s = st(buf)
  if not s or not s.rpc then return end
  s.rpc:abort(function(aborted, err)
    if err then
      vim.notify('icarus abort: ' .. err, vim.log.levels.WARN)
    else
      set_status(buf, 'idle', aborted and 'aborted' or 'nothing to abort')
    end
  end)
end

function M.close(buf)
  local s = st(buf)
  if not s then return end
  if s.rpc then s.rpc:close() end
  s.rpc = nil
  if s.win and vim.api.nvim_win_is_valid(s.win) then
    vim.api.nvim_win_close(s.win, true)
  end
  chats[buf] = nil
end

--- Status snapshot for tests and for :IcarusStatus.
function M.state(buf)
  local s = st(buf)
  if not s then return nil end
  return {
    status = s.status,
    session_id = s.session_id,
    entries = s.entries,
    streaming = s.stream ~= nil,
  }
end

function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', M.opts, opts or {})
end

return M
