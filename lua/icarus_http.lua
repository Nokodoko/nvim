-- Async HTTP/1.1 client for editor inference requests (minuet completion).
--
-- WHY: minuet's openai_base backend shells out to `curl` per request via
-- vim.system. The spawn itself (fork + exec) costs ~1.5 ms warm and 15-65 ms
-- when the binary's pages have gone cold (measured 2026-09-29, monty setup):
-- that is a synchronous stall on the UI loop at every request START, which is
-- exactly the "momentary pause" felt when a suggestion fires. The transfer
-- after spawn is already async, so the fix is to remove the fork: plain
-- vim.loop TCP, no subprocess, no C stack growth, ~0 ms on the UI thread.
--
-- Scope: exactly what minuet needs -- HTTP (no TLS), POST with a JSON body
-- from a file, SSE/chunked responses, timeout, cancel. Not a general client.
-- Keep-alive is used; a failed reuse transparently retries once on a fresh
-- connection (llama.cpp closes idle keep-alive connections).

local uv = vim.loop

local M = {}

local function parse_url(url)
  local scheme, rest = url:match('^(%a+)://(.+)$')
  if not scheme then return nil, 'missing scheme: ' .. tostring(url) end
  if scheme:lower() ~= 'http' then return nil, 'unsupported scheme: ' .. scheme end
  local hostport, path = rest:match('^([^/]*)(/.*)$')
  if not hostport then return nil, 'missing path: ' .. url end
  local host, port = hostport:match('^([^:]+):(%d+)$')
  if not host then host, port = hostport, '80' end
  if host == '' then return nil, 'missing host: ' .. url end
  return { host = host, port = tonumber(port), path = path }
end

-- DNS: async, cached forever (LAN hosts; a stale entry self-heals via the
-- fresh-connection retry below). getaddrinfo runs on libuv's thread pool, so
-- even a cold lookup never touches the UI loop.
local dns_cache = {}

local function resolve(host, cb)
  local ip = dns_cache[host]
  if ip then
    vim.schedule(function() cb(nil, ip) end)
    return
  end
  uv.getaddrinfo(host, nil, { family = 'inet', socktype = 'stream' }, function(err, res)
    if err or not res or #res == 0 then
      cb(err or 'no A record')
      return
    end
    local addr = res[1].addr
    dns_cache[host] = addr
    cb(nil, addr)
  end)
end

local header_value = function(headers, name)
  local want = name:lower()
  for k, v in pairs(headers or {}) do
    if k:lower() == want then return v end
  end
  return nil
end

-- Parse a complete "HTTP/1.1 200 OK\r\n...headers\r\n" prefix.
-- Returns status, headers_table, body_start_offset, or nil if incomplete.
local function parse_head(buf)
  local head_end = buf:find('\r\n\r\n', 1, true)
  if not head_end then return nil end
  local head = buf:sub(1, head_end - 1)
  local status = tonumber(head:match('^HTTP/%d%.%d (%d%d%d)'))
  if not status then return nil end
  local headers = {}
  for line in head:gmatch('[^\r\n]+') do
    local k, v = line:match('^([^:]+):%s*(.*)$')
    if k and not headers[k:lower()] then headers[k:lower()] = v end
  end
  return status, headers, head_end + 4
end

-- Incremental chunked-transfer decoder. feed(chunk) appends; done() when the
-- terminating 0-chunk is seen.
local function chunked_decoder()
  local acc = ''
  local out = {}
  local state = 'size'
  local need = 0
  local finished = false

  local function pump()
    while not finished do
      if state == 'size' then
        local s, e = acc:find('\r\n', 1, true)
        if not s then return end
        local hex = acc:sub(1, s - 1):match('^%x+')
        need = tonumber(hex, 16) or 0
        acc = acc:sub(e + 1)
        if need == 0 then
          finished = true
          return
        end
        state = 'data'
      elseif state == 'data' then
        if #acc < need + 2 then return end -- +2: trailing CRLF
        out[#out + 1] = acc:sub(1, need)
        acc = acc:sub(need + 3)
        state = 'size'
      end
    end
  end

  return {
    feed = function(chunk)
      acc = acc .. chunk
      pump()
    end,
    finished = function() return finished end,
    body = function() return table.concat(out) end,
  }
end

---@class IcarusHttpRequest
---@field cancel fun(): nil
---@field done boolean

--- POST a JSON body (read from `body_file`) to `url`.
--- cb(err, status, body): err is a string on transport failure; on success
--- status is the HTTP code and body the full response text.
---@param url string
---@param headers table<string,string>
---@param body_file string path containing the raw request body
---@param opts? { timeout_ms?: integer }
---@return IcarusHttpRequest
function M.post_json(url, headers, body_file, opts)
  opts = opts or {}
  local req = { done = false }
  local sock = uv.new_tcp()
  local timer = uv.new_timer()
  local decoder, expect_len, content_len, status_
  local acc = ''
  local settled = false

  local function teardown()
    req.done = true
    if not timer:is_closing() then timer:stop(); timer:close() end
    if not sock:is_closing() then sock:close() end
  end

  local function settle(err, status, body)
    if settled then return end
    settled = true
    teardown()
    if req.on_done then req.on_done(err) end
    if req.cb then
      -- Callers (minuet) run nvim API calls in the callback; libuv read
      -- callbacks are not a safe API context, so hop to the main loop.
      vim.schedule(function()
        local ok, cerr = pcall(req.cb, err, status, body)
        if not ok then vim.schedule(function() error(cerr) end) end
      end)
    end
  end

  local function on_body_chunk(chunk)
    if decoder then
      decoder.feed(chunk)
      if decoder.finished() then settle(nil, status_, decoder.body()) end
    else
      acc = acc .. chunk
      if #acc >= content_len then settle(nil, status_, acc:sub(1, content_len)) end
    end
  end

  -- Connect (or reuse), write, read. `retried` guards the single keep-alive
  -- retry so a dead server cannot loop us.
  function req.go(retried)
    resolve(parse_url(url).host, function(derr, ip)
      if settled then return end
      if derr then settle('dns: ' .. tostring(derr)) return end
      local parsed = parse_url(url)
      sock:connect(ip, parsed.port, function(cerr)
        if settled then return end
        if cerr then
          settle('connect: ' .. cerr)
          return
        end
        local f = io.open(body_file, 'rb')
        if not f then settle('body: cannot read ' .. body_file) return end
        local body = f:read('*a')
        f:close()

        -- Caller headers override the defaults (minuet passes its own
        -- Content-Type and Authorization). Keyed by lowercase so a caller's
        -- Content-Type REPLACES the default instead of duplicating it: a
        -- repeated Content-Type is invalid per RFC 9110 5.5 (it is not a
        -- comma-list field) and stricter proxies reject it. The curl path
        -- this replaces sent it once, so once is the faithful behaviour.
        local hdr = {
          ['content-type'] = 'application/json',
          ['connection'] = 'keep-alive',
          ['accept'] = '*/*',
        }
        -- Preserve the caller's casing so the wire bytes match what the curl
        -- path sent (`Content-Type:`, not `content-type:`). Header names are
        -- case-insensitive, but changing them needlessly makes a curl-vs-TCP
        -- diff harder to read when a request misbehaves.
        local name = {
          ['content-type'] = 'Content-Type',
          ['connection'] = 'Connection',
          ['accept'] = 'Accept',
        }
        for k, v in pairs(headers or {}) do
          local lk = k:lower()
          hdr[lk] = v
          name[lk] = k
        end
        -- Host must carry a non-default port (RFC 9110 7.2); omitting it made
        -- a `monty:8085` request name the wrong authority. Content-Length is
        -- computed from the body, so both stay ours and lead the header block
        -- in a fixed order (pairs() order is not deterministic).
        local lines = {
          'POST ' .. parsed.path .. ' HTTP/1.1',
          'Host: ' .. parsed.host .. ((parsed.port ~= 80) and (':' .. parsed.port) or ''),
          'Content-Length: ' .. #body,
        }
        local order = { 'content-type', 'connection', 'accept' }
        local seen = {}
        for _, k in ipairs(order) do
          if hdr[k] then lines[#lines + 1] = name[k] .. ': ' .. hdr[k]; seen[k] = true end
        end
        -- Any caller header we do not know about (e.g. Authorization).
        local extra = {}
        for k in pairs(hdr) do if not seen[k] then extra[#extra + 1] = k end end
        table.sort(extra)
        for _, k in ipairs(extra) do lines[#lines + 1] = name[k] .. ': ' .. hdr[k] end
        local head = table.concat(lines, '\r\n') .. '\r\n\r\n'

        acc = ''
        decoder, expect_len, content_len, status_ = nil, false, nil, nil

        sock:read_start(function(rerr, chunk)
          if settled then return end
          if rerr then settle('read: ' .. rerr) return end
          if not chunk then
            -- EOF. A keep-alive socket reused against a closed server-side
            -- half yields EOF before any byte: retry once on a fresh socket.
            if not retried and acc == '' then
              if not sock:is_closing() then sock:close() end
              sock = uv.new_tcp()
              req.go(true)
              return
            end
            -- Premature EOF otherwise: deliver what we have (curl -f would
            -- have failed; minuet tolerates a partial/empty body).
            settle(nil, status_, decoder and decoder.body() or acc)
            return
          end
          if not expect_len then
            acc = acc .. chunk
            local st, hdrs, off = parse_head(acc)
            if not st then return end
            status_ = st
            expect_len = true
            local te = header_value(hdrs, 'transfer-encoding')
            if te and te:lower():find('chunked') then
              decoder = chunked_decoder()
              local rest = acc:sub(off)
              acc = ''
              on_body_chunk(rest)
              if decoder.finished() then settle(nil, status_, decoder.body()) end
            else
              content_len = tonumber(header_value(hdrs, 'content-length') or '') or 0
              local rest = acc:sub(off)
              acc = ''
              on_body_chunk(rest)
            end
          else
            on_body_chunk(chunk)
          end
        end)

        sock:write(head .. body)
      end)
    end)
  end

  if opts.timeout_ms and opts.timeout_ms > 0 then
    timer:start(opts.timeout_ms, 0, function() settle('timeout') end)
  end

  function req.cancel()
    settle('cancelled')
  end

  req.go(false)
  return req
end

return M
