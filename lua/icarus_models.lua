-- Shared fetch/flatten helper for icarus's live provider/model catalog.
-- Single source of truth for "how to get the same list as icarus's Meh-M
-- model picker" (GET /provider on a running `icarus serve`; there is no
-- working CLI equivalent). Consumed by:
--   - after/snippets/markdown.lua (the `models` markdown snippet body)
--   - lua/icarus_model_picker.lua (the Telescope provider/model picker)

local M = {}

M.addr = '127.0.0.1:7654'

--- Fetch and decode the icarus serve provider catalog. BLOCKS the UI loop for
--- up to `timeout_s`: only for callers the user explicitly invoked and is
--- waiting on (the model picker). Anything that runs implicitly -- snippet
--- loaders, completion sources, autocmds -- must use `cached()` instead.
---
--- `timeout_s` bounds the curl call. The default (2s) is deliberately short:
--- the interactive caller (model picker) would rather show its fallback than
--- stall the UI for long. It is NOT a safe budget for a request that
--- must succeed -- GET /provider takes ~4-7s when serve's own 30s model cache
--- (modelsCacheTTL in cmd/icarus/serve_chat.go) is cold, and a cold response
--- measured 1.6s even once warm, so 2s is close to the line. Callers that can
--- wait (the async endpoint refresher) pass a larger value.
---
--- A timed-out call is not wasted: serve keeps running discovery after the
--- client hangs up, so the next request inside the 30s window is fast. That is
--- why the async refresher can afford to be opportunistic.
---@param timeout_s? number curl --max-time, seconds (default 2)
---@return table|nil decoded `{all, default, connected}` JSON, or nil on any failure
---  (unreachable endpoint, non-zero exit, empty body, or invalid JSON).
function M.fetch(timeout_s)
  local raw = vim.fn.system({
    'curl', '-sf', '--max-time', tostring(timeout_s or 2),
    'http://' .. M.addr .. '/provider',
  })
  if vim.v.shell_error ~= 0 or vim.trim(raw or '') == '' then return nil end

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= 'table' then return nil end
  return data
end

-- Last successful catalog and when it landed; shared by every `cached()` caller.
local cache = { data = nil, at = -math.huge, inflight = false }

--- Refresh the cache in the background. Never blocks: `vim.system` runs curl
--- off the loop and the decode happens in a scheduled callback.
---@param timeout_s? number curl --max-time, seconds (default 8: cold serve is 4-7s)
---@param on_done? fun(data: table|nil) called on the main loop when the request settles
function M.refresh(timeout_s, on_done)
  if cache.inflight then return end
  cache.inflight = true
  vim.system({
    'curl', '-sf', '--max-time', tostring(timeout_s or 8),
    'http://' .. M.addr .. '/provider',
  }, { text = true }, function(out)
    vim.schedule(function()
      cache.inflight = false
      local data
      if out.code == 0 and vim.trim(out.stdout or '') ~= '' then
        local ok, decoded = pcall(vim.json.decode, out.stdout)
        if ok and type(decoded) == 'table' then data = decoded end
      end
      if data ~= nil then
        cache.data, cache.at = data, vim.uv.now() / 1000
      end
      if on_done then on_done(data) end
    end)
  end)
end

--- The catalog as last seen, without ever blocking.
---
--- Returns the cached catalog (nil until the first background fetch lands)
--- and, when the copy is older than `max_age_s`, kicks off ONE background
--- refresh so the next call is fresher. This is what the markdown `models`
--- snippet uses: mini.snippets calls function snippets on every prepare,
--- i.e. on every completion round while typing, and a synchronous curl there
--- (measured 1.6-2.0s per call, several per sentence) froze the editor --
--- typed text appeared only after the request returned.
---@param max_age_s? number seconds a cached copy stays fresh (default 30)
---@return table|nil
function M.cached(max_age_s)
  if vim.uv.now() / 1000 - cache.at > (max_age_s or 30) then M.refresh() end
  return cache.data
end

--- Flatten a fetched catalog into a sorted list of "provider/model" strings.
---@param data table Decoded catalog from `M.fetch()`.
---@return string[]
function M.flatten(data)
  local out = {}
  for _, provider in ipairs((data or {}).all or {}) do
    for model_id, _ in pairs(provider.models or {}) do
      table.insert(out, provider.id .. '/' .. model_id)
    end
  end
  table.sort(out)
  return out
end

return M
