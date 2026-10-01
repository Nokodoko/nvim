-- :checkhealth minuet -- minuet-ai.nvim ships no health module, so
-- :checkhealth reported "No healthcheck found". This one lives in the config
-- (earlier on 'runtimepath') and checks the endpoint the minuet transform in
-- plugin/40_plugins.lua actually sends to. Blocking curl is fine here:
-- :checkhealth is an explicit, synchronous command.
local M = {}

function M.check()
  vim.health.start('minuet (local inference)')

  local loaded, minuet = pcall(require, 'minuet')
  if not loaded or not minuet.config then
    vim.health.error('minuet-ai.nvim is not set up (g:no_minuet set?)')
    return
  end

  local opts = minuet.config.provider_options.openai_compatible
  local ok, req = pcall(opts.transform[1], { headers = {}, body = {} })
  if not ok then
    vim.health.error('transform failed: ' .. tostring(req))
    return
  end
  vim.health.info('endpoint: ' .. req.end_point)
  vim.health.info('model: ' .. tostring(req.body.model))

  local base = req.end_point:gsub('/v1/chat/completions$', '')
  local res = vim.system({ 'curl', '-sf', '--max-time', '3', base .. '/health' }):wait()
  if res.code == 0 then
    vim.health.ok('server healthy: ' .. vim.trim(res.stdout or ''))
  else
    vim.health.error(string.format('%s/health unreachable (curl exit %d)', base, res.code))
  end
end

return M
