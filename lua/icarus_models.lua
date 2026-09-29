-- Shared fetch/flatten helper for icarus's live provider/model catalog.
-- Single source of truth for "how to get the same list as icarus's Meh-M
-- model picker" (GET /provider on a running `icarus serve`; there is no
-- working CLI equivalent). Consumed by:
--   - after/snippets/markdown.lua (the `models` markdown snippet body)
--   - lua/icarus_model_picker.lua (the Telescope provider/model picker)

local M = {}

M.addr = '127.0.0.1:7654'

--- Fetch and decode the icarus serve provider catalog.
---
--- `timeout_s` bounds the curl call. The default (2s) is deliberately short:
--- the two interactive callers (snippet body, model picker) would rather show
--- their fallback than stall the UI. It is NOT a safe budget for a request that
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
