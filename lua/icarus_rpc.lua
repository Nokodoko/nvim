-- icarus_rpc: a JSON-RPC 2.0 client for `icarus --mode rpc`.
--
-- WHY THIS EXISTS. The ChatGPT.nvim chat that <C-e> used to open talks to a
-- bare llama.cpp endpoint: it is a text completion with a chat history, so it
-- has no tools at all. `icarus --mode rpc` is the pi-rpc adapter (internal/
-- pirpc) whose backend (cmd/icarus/rpc_backend.go) builds its agent with
-- cli.BuildAgent and runs it with agent.Loop.Run -- the SAME loop the REPL and
-- the web chat run. So a session opened through this client has the full
-- regular-icarus tool catalog: bash, the file tools, the ob1 MCP tools
-- (mcp__ob1__ob_query, ob_read, ob2_search, ob_graph_query, ob_assist, ...),
-- and skills. Verified live against the installed binary before writing this:
-- a prompt that asked for `echo TOOLPROBE-OK` executed the bash tool, and the
-- session's tool list contained the ob1 tools.
--
-- WHAT IS NOT AVAILABLE. rpcBackend implements pirpc.Backend only, not
-- pirpc.ExtensionBackend, so extension/register, context/inject, diff/apply,
-- session/subscribe, tool/register and memory/inject answer -32601. Anything
-- buffer-side therefore has to be done HERE, in the editor: context goes in by
-- being prepended to the prompt text, and replies land in the buffer through
-- the UI. Do not add code that assumes those methods exist.
--
-- PROTOCOL (internal/pirpc/types.go, verified on the wire):
--   one JSON object per line on stdin; one JSON object per line on stdout.
--   A streaming prompt emits request-less-looking notifications that REUSE the
--   originating request id, so id alone does not identify a response -- the
--   terminal frame for a stream is {"result":{"done":true}}.
--
-- PROCESS MODEL. One child per chat buffer, kept alive across prompts so the
-- icarus session (and therefore its context) persists. The backend serialises
-- prompts per session, so a second prompt while one is in flight is refused
-- locally rather than queued invisibly.

local M = {}

M.bin = vim.env.ICARUS_BIN or 'icarus'

-- Extra argv for every chat session. --skill entries are appended per chat by
-- icarus_chat (see M.new opts.skills).
M.extra_args = {}

-- A timeout has to accommodate a tool-using turn, not a token: a bash round
-- trip inside a turn is normal.
M.request_timeout_ms = 300000

local json = vim.json

-- ---------------------------------------------------------------- transport

--- Start an `icarus --mode rpc` child and return its handle.
--- @param opts table? { args: string[]?, on_notification: fn(line)?, on_exit: fn(code, stderr)? }
function M.spawn(opts)
  opts = opts or {}
  local argv = { M.bin, '--mode', 'rpc' }
  for _, a in ipairs(M.extra_args) do argv[#argv + 1] = a end
  for _, a in ipairs(opts.args or {}) do argv[#argv + 1] = a end

  local partial = ''
  local stderr_partial = ''

  -- NOTE on the two API shapes this build actually has (runtime/lua/vim/_core/
  -- system.lua): SystemObj:wait() BLOCKS and takes no callback, and
  -- SystemObj:write() returns nothing. So exit notification comes from the
  -- third argument of vim.system(), and write success is tested with
  -- is_closing() -- not with the return value of write().
  local child = { dead = false }

  local proc = vim.system(argv, {
    stdin = true,
    -- vim.schedule_wrap is REQUIRED, not an optimisation: uv stream callbacks
    -- run in a "fast event context" where the editor API is forbidden, so a
    -- handler that touches a buffer dies with E5560 ("nvim_buf_is_valid must
    -- not be called in a fast event context"). Scheduling keeps frame order
    -- (the queue is FIFO) and moves the work where API calls are legal.
    stdout = vim.schedule_wrap(function(err, data)
      if err or not data then return end
      partial = partial .. data
      -- Frame on newline only: a JSON object may legitimately contain no
      -- newline, and a line may arrive split across reads.
      while true do
        local line = partial:match('^(.-)\n')
        if not line then break end
        partial = partial:sub(#line + 2)
        if line ~= '' and opts.on_notification then
          -- Decode defensively: a malformed line must not kill the stream.
          local ok, msg = pcall(json.decode, line)
          if ok then opts.on_notification(msg, line) end
        end
      end
    end),
    stderr = function(_, data)
      if not data then return end
      -- icarus logs to stderr (slog + agent WARNs). Keep the tail for the UI;
      -- it is the only place a dropped tool call shows up.
      stderr_partial = (stderr_partial .. data):sub(-8192)
    end,
  }, vim.schedule_wrap(function(res)
    -- The exit callback runs from the uv process handler like stdout does, so
    -- it needs the same schedule_wrap before anything may touch a buffer.
    child.dead = true
    if opts.on_exit then opts.on_exit(res and res.code, stderr_partial) end
  end))

  child.proc = proc
  child.get_stderr = function() return stderr_partial end
  return child
end

--- Write one request line. Returns false if the child is gone.
function M.write(child, obj)
  if not child or child.dead or not child.proc or child.proc:is_closing() then return false end
  local ok, line = pcall(json.encode, obj)
  if not ok then return false end
  -- write() has no return value in this build; a closed handle is the failure
  -- mode we can actually observe, and the exit callback covers the rest.
  local wok, werr = pcall(function() child.proc:write(line .. '\n') end)
  if not wok then
    child.dead = true
    return false
  end
  return true
end

-- ------------------------------------------------------------------ session
--
-- A session owns one child and the request/response correlation for it.

local Session = {}
Session.__index = Session

--- Open a chat session (spawns the child and waits for nothing -- icarus
--- answers `ping` as soon as the RPC server is up, so ping doubles as the
--- readiness probe).
--- @param opts table? { args, skills: string[], on_stderr_line: fn, on_exit: fn }
--- @return Session, err
function M.open(opts)
  opts = opts or {}
  local self = setmetatable({
    next_id = 1,
    pending = {},          -- id -> { on_update, done }
    session_id = nil,      -- icarus session id, learned from the first reply
    skills = opts.skills or {},
    log = {},              -- ring of human-readable activity lines for the UI
    on_log = opts.on_log,
    on_exit = opts.on_exit,
    closed = false,
  }, Session)

  local args = {}
  for _, s in ipairs(self.skills) do
    args[#args + 1] = '--skill'
    args[#args + 1] = s
  end

  self.child = M.spawn({
    args = args,
    on_notification = function(msg, raw) self:_dispatch(msg, raw) end,
    on_exit = function(code, stderr)
      self.closed = true
      -- Fail every waiter instead of letting it time out.
      for id, entry in pairs(self.pending) do
        self.pending[id] = nil
        if entry.on_done then entry.on_done(nil, 'icarus exited (code ' .. tostring(code) .. ')') end
      end
      if self.on_exit then self.on_exit(code, stderr) end
    end,
  })

  return self, nil
end

function Session:log_line(kind, text)
  if not text or text == '' then return end
  self.log[#self.log + 1] = { kind = kind, text = text }
  if #self.log > 400 then table.remove(self.log, 1) end
  if self.on_log then self.on_log(kind, text) end
end

--- Route one decoded stdout frame. Every frame carries the originating request
--- id, including the streaming notifications, so `pending[id]` is the router.
---
--- Two completion rules, and they are different on purpose:
---   * a plain request (ping/version/abort) is answered by exactly ONE frame,
---     so it resolves as soon as that frame arrives -- its result has no
---     `type` and no `done`.
---   * a streaming prompt is a sequence (message_start, N x message_update,
---     message_end) terminated by the synthetic {"done":true} frame, so it
---     must NOT resolve on the first frame.
function Session:_dispatch(msg, raw)
  local id = msg.id
  -- id may be a JSON number or string; normalise to a string key.
  if id == nil then return end
  id = tostring(id)
  local entry = self.pending[id]
  if not entry then return end

  if msg.error then
    self.pending[id] = nil
    if entry.on_done then entry.on_done(nil, (msg.error.message or 'rpc error') .. ' (' .. tostring(msg.error.code) .. ')') end
    return
  end

  local result = msg.result or {}

  if not entry.stream then
    -- Single-frame request: whatever came back is the answer.
    self.pending[id] = nil
    if result.session_id then self.session_id = result.session_id end
    if entry.on_done then entry.on_done(result, nil) end
    return
  end

  -- Terminal frame of a streaming prompt: {"done":true} and nothing else.
  if result.done then
    self.pending[id] = nil
    if entry.on_done then entry.on_done({ done = true, text = entry.accum or '', stop_reason = entry.stop_reason }, nil) end
    return
  end

  if result.type == 'message_start' then
    if result.session_id then self.session_id = result.session_id end
    if entry.on_update then entry.on_update('start', result) end
  elseif result.type == 'message_update' then
    if result.session_id then self.session_id = result.session_id end
    local delta = result.delta
    if delta and delta ~= '' then
      -- rpc_backend.PromptStream forwards live `stream.chunk` deltas AND then
      -- emits the completed turn as ONE MORE message_update carrying the full
      -- text, immediately before message_end. Accumulating both duplicates the
      -- reply (observed: "STREAM-PROBE-7STREAM-PROBE-7"). The authoritative
      -- full text is that last frame, so when a frame arrives that already
      -- contains everything accumulated so far as a prefix, it REPLACES the
      -- accumulation instead of appending to it.
      local acc = entry.accum or ''
      if #delta >= #acc and delta:sub(1, #acc) == acc then
        entry.accum = delta
      else
        entry.accum = acc .. delta
      end
      if entry.on_update then entry.on_update('delta', result) end
    end
  elseif result.type == 'message_end' then
    -- message_end is not the terminal frame ({"done":true} follows), but it
    -- carries stop_reason, which the UI wants before the final frame.
    entry.stop_reason = result.stop_reason
    if entry.on_update then entry.on_update('end', result) end
  elseif entry.on_update then
    entry.on_update('result', result)
  end
end

--- Low-level single request. `cb(result, err)` is called on the main loop.
function Session:request(method, params, cb, opts)
  opts = opts or {}
  if self.closed then
    vim.schedule(function() cb(nil, 'icarus session is closed') end)
    return
  end
  local id = self.next_id
  self.next_id = self.next_id + 1
  local req = { jsonrpc = '2.0', id = id, method = method }
  if params then req.params = params end

  -- `local entry` on its own line is load-bearing: the on_done closure below
  -- reads entry.timer, and a local declared in the same statement as the table
  -- constructor is NOT in scope inside that constructor's functions (it would
  -- resolve to a nil global).
  local entry
  entry = { on_done = function(res, err)
    if entry.timer then entry.timer:stop(); entry.timer = nil end
    if cb then cb(res, err) end
  end }

  self.pending[tostring(id)] = entry
  if not M.write(self.child, req) then
    self.pending[tostring(id)] = nil
    vim.schedule(function() cb(nil, 'cannot write to icarus (child gone)') end)
    return
  end

  local timer = vim.uv.new_timer()
  entry.timer = timer
  timer:start(opts.timeout_ms or M.request_timeout_ms, 0, vim.schedule_wrap(function()
    if self.pending[tostring(id)] then
      self.pending[tostring(id)] = nil
      timer:stop()
      cb(nil, method .. ': timed out')
    end
  end))
end

--- Streaming prompt. `on_update(kind, result)` fires for start/delta/end;
--- `on_done(result, err)` fires once.
--- @param text string
--- @param handlers table { on_update: fn(kind, result), on_done: fn(result, err) }
function Session:prompt(text, handlers)
  handlers = handlers or {}
  if self.closed then
    vim.schedule(function() if handlers.on_done then handlers.on_done(nil, 'icarus session is closed') end end)
    return
  end
  local id = self.next_id
  self.next_id = self.next_id + 1
  local entry = {
    on_update = handlers.on_update,
    on_done = handlers.on_done,
    stream = true,
  }
  self.pending[tostring(id)] = entry

  local ok = M.write(self.child, {
    jsonrpc = '2.0', id = id, method = 'prompt',
    params = { session_id = self.session_id, prompt = text, stream = true },
  })
  if not ok then
    self.pending[tostring(id)] = nil
    vim.schedule(function()
      if handlers.on_done then handlers.on_done(nil, 'cannot write to icarus (child gone)') end
    end)
    return
  end

  local timer = vim.uv.new_timer()
  entry.timer = timer
  timer:start(M.request_timeout_ms, 0, vim.schedule_wrap(function()
    if self.pending[tostring(id)] then
      self.pending[tostring(id)] = nil
      timer:stop()
      if handlers.on_done then
        handlers.on_done({ text = entry.accum or '', stop_reason = 'timeout' }, 'prompt timed out')
      end
    end
  end))
end

function Session:abort(cb)
  if not self.session_id then
    if cb then cb(false, 'no session id yet') end
    return
  end
  self:request('abort', { session_id = self.session_id }, function(res, err)
    if cb then cb(res and res.aborted, err) end
  end, { timeout_ms = 5000 })
end

function Session:ping(cb)
  self:request('ping', nil, cb, { timeout_ms = 5000 })
end

function Session:version(cb)
  self:request('version', nil, cb, { timeout_ms = 5000 })
end

--- Close the chat: kill the child. Safe to call twice.
function Session:close()
  if self.closed then return end
  self.closed = true
  self.pending = {}
  if self.child and self.child.proc then
    pcall(function() self.child.proc:kill('term') end)
  end
end

M.Session = Session

--- One-shot prompt with no persistent session (`--no-session` semantics are
--- the caller's business; this just opens, prompts, closes).
function M.oneshot(text, cb, opts)
  opts = opts or {}
  local sess = M.open(opts)
  sess:prompt(text, {
    on_update = opts.on_update,
    on_done = function(res, err)
      sess:close()
      if cb then cb(res, err) end
    end,
  })
  return sess
end

return M
