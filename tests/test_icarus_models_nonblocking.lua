-- Regression test: the markdown `models` function snippet must never block.
-- Run with: nvim --headless -c "luafile tests/test_icarus_models_nonblocking.lua" -c "qa!"
--
-- History: it called icarus_models.fetch() (a synchronous curl with a 2s
-- --max-time) and mini.snippets invokes function snippets on every prepare,
-- i.e. on every completion round while typing -- so every sentence typed in a
-- markdown buffer froze the editor for 1.6-2s (2026-09-29, found via the
-- SLOW-call wrapper in plugin/00_uilog.lua).

local passed, failed = 0, 0
local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print('PASS: ' .. name)
  else failed = failed + 1; print('FAIL: ' .. name .. '\n      ' .. tostring(err)) end
end

local snippets = dofile(vim.fn.stdpath('config') .. '/after/snippets/markdown.lua')

check('models snippet returns in well under a frame, cold and warm', function()
  local worst = 0
  for _ = 1, 5 do
    local t = vim.uv.hrtime()
    local snip = snippets.models({})
    local ms = (vim.uv.hrtime() - t) / 1e6
    if ms > worst then worst = ms end
    assert(snip.prefix == 'models' and snip.body ~= nil, 'snippet shape')
  end
  assert(worst < 20, string.format('worst call took %.1f ms (limit 20)', worst))
end)

check('icarus_models.cached() never blocks even when the endpoint is unreachable', function()
  local m = require('icarus_models')
  local saved = m.addr
  m.addr = '127.0.0.1:1' -- nothing listens here
  local t = vim.uv.hrtime()
  m.cached(0) -- stale => triggers a refresh
  local ms = (vim.uv.hrtime() - t) / 1e6
  m.addr = saved
  assert(ms < 20, string.format('cached() took %.1f ms', ms))
end)

print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
