-- Live inference endpoint for the editor: whatever model icarus's web surface
-- is on RIGHT NOW. icarus's /swap and /fleet change which backend answers;
-- icarus's liveness walk over routing.surface_defaults["web"] then moves its
-- `default` (GET /provider) to the first pin that answers. Every editor
-- request resolves through here, so ChatGPT.nvim and claude_prompt
-- follow a swap on their next request -- no config rewrite, no nvim restart.
--
-- Resolution: GET /provider -> default {provider = model}; the provider must
-- be `local` (cloud providers speak OAuth/CLI, not a raw OpenAI endpoint);
-- its base_url and api_key_env come from ~/.icarus/settings.json, the key
-- value from $ENV or ~/.config/icarus/serve.env (the same file icarus-serve
-- loads). llama.cpp ignores the bearer token; vLLM (DeepSeek) enforces it.
--
-- Any failure returns the last good endpoint, else the static fallback the
-- plugin blocks were configured with -- the editor never loses completion
-- because icarus serve is restarting.

local M = {}

M.settings_path = vim.fn.expand('~/.icarus/settings.json')
M.env_path = vim.fn.expand('~/.config/icarus/serve.env')
-- A resolve costs one localhost curl; manual-trigger completion can fire
-- several times a second, so reuse an answer this many seconds.
M.ttl_s = 10

-- How long the BACKGROUND refresh waits for GET /provider. It can be generous
-- because nothing on the UI loop waits for it. It must exceed serve's cold
-- discovery time (~4-7s: it probes every configured provider, and its own
-- snapshot cache only lives 30s -- modelsCacheTTL in cmd/icarus/serve_chat.go),
-- otherwise the refresh times out exactly when it is most needed.
M.refresh_timeout_s = 12

-- Don't retry a failed refresh for this long. Without it a DEAD serve fails
-- curl in ~0ms (connection refused), which clears `refreshing` immediately, and
-- manual-trigger completion would then spawn a fresh curl on every keypress.
M.retry_backoff_s = 30

local cache = { at = 0, ep = nil }
local last_good = nil
local refreshing = false
-- -math.huge, not 0: vim.uv.now() is a monotonic clock with an ARBITRARY origin
-- (measured ~1997s here, i.e. not epoch), so a 0 sentinel would count as a real
-- recent failure whenever nvim starts within retry_backoff_s of that origin and
-- would block the very first refresh.
local last_fail_at = -math.huge

local function read_json(path)
  local f = io.open(path, 'r')
  if not f then return nil end
  local raw = f:read('*a')
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  return ok and type(data) == 'table' and data or nil
end

local function env_value(name)
  if vim.env[name] and vim.env[name] ~= '' then return vim.env[name] end
  local f = io.open(M.env_path, 'r')
  if not f then return nil end
  for line in f:lines() do
    local k, v = line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
    if k == name then
      f:close()
      return (v:gsub('^["\'](.*)["\']$', '%1'))
    end
  end
  f:close()
  return nil
end

--- Turn a fetched catalog into an endpoint. Pure: no I/O beyond reading
--- settings.json, so it is safe to call from an async callback.
local function extract(data)
  if not data then return nil end
  local provider, model = next(data.default or {})
  if not provider then return nil end
  for _, p in ipairs(data.all or {}) do
    if p.id == provider and not p['local'] then return nil end
  end
  local settings = read_json(M.settings_path)
  local pcfg = settings and settings.providers and settings.providers[provider]
  if not pcfg or type(pcfg.base_url) ~= 'string' then return nil end
  local key = pcfg.api_key_env and env_value(pcfg.api_key_env) or nil
  return {
    provider = provider,
    model = model,
    base = (pcfg.base_url:gsub('/+$', ''):gsub('/v1$', '')),
    key = key or 'local-no-auth',
  }
end

--- Ask serve, off the UI loop, and update the cache when the answer lands.
--- Never blocks: `resolve` serves the current cache meanwhile. Coalesced so a
--- burst of completions starts at most one request.
local function refresh_async()
  if refreshing then return end
  local now = vim.uv.now() / 1000
  if now - last_fail_at < M.retry_backoff_s then return end
  refreshing = true
  vim.system(
    {
      'curl', '-sf', '--max-time', tostring(M.refresh_timeout_s),
      'http://' .. require('icarus_models').addr .. '/provider',
    },
    { text = true },
    function(res)
      refreshing = false
      local raw = res and res.stdout or ''
      local ok, data = pcall(vim.json.decode, raw)
      local ep = ok and extract(data) or nil
      if ep then
        last_good = ep
        cache.ep, cache.at = ep, vim.uv.now() / 1000
      else
        -- Serve down, still booting, or defaulting to a cloud provider: back
        -- off rather than hammering it on every completion.
        last_fail_at = vim.uv.now() / 1000
      end
    end
  )
end

--- The live endpoint `{provider, model, base, key}`, or `fallback` (a table of
--- the same shape) when icarus cannot be asked and nothing was resolved yet.
---
--- NEVER BLOCKS. This runs on synchronous request-construction paths
--- (claude_prompt/api.lua and ChatGPT.nvim's host/model commands resolve
--- inline before building the request), so a blocking fetch here freezes the
--- editor for the whole duration -- which is why a stale-but-instant answer
--- plus a background refresh beats a fresh answer here. A /swap is therefore
--- picked up within one TTL, not on the very next keypress.
function M.resolve(fallback)
  local now = vim.uv.now() / 1000
  if cache.ep and now - cache.at < M.ttl_s then return cache.ep end
  -- Cache is stale: hand back what we last knew and go get a better answer.
  refresh_async()
  return cache.ep or last_good or fallback
end

--- Resolve synchronously, waiting up to `timeout_s` for serve. For explicit
--- user requests (:IcarusEndpoint), where waiting is the point. Not for
--- request paths -- it freezes the UI for the whole timeout when cold.
function M.resolve_blocking(fallback, timeout_s)
  local ep = extract(require('icarus_models').fetch(timeout_s or M.refresh_timeout_s))
  if ep then
    last_good = ep
    cache.ep, cache.at = ep, vim.uv.now() / 1000
    return ep
  end
  return cache.ep or last_good or fallback
end

--- Drop the cached answer so the next request re-asks icarus.
function M.invalidate() cache.at, cache.ep = 0, nil end

--- chat_template_kwargs that switch reasoning off on either server family:
--- llama.cpp reads `enable_thinking` and ignores `thinking`; vLLM's DeepSeek
--- template reads `thinking`. Sending both is harmless to each.
M.no_thinking = { enable_thinking = false, thinking = false }

vim.api.nvim_create_user_command('IcarusEndpoint', function()
  M.invalidate()
  -- Explicit request: wait for the truth instead of showing a stale answer.
  local ep = M.resolve_blocking(nil)
  if ep then
    vim.notify(string.format('icarus endpoint: %s/%s @ %s', ep.provider or '?', ep.model, ep.base))
  else
    vim.notify('icarus endpoint: unresolved (serve down or cloud default)', vim.log.levels.WARN)
  end
end, { desc = 'Show the live icarus inference endpoint the editor uses' })

return M
