local uv = vim.uv or vim.loop
if not uv or not vim.g.__startup_hrtime then
  return
end

local log_path = vim.fn.stdpath('state') .. '/startup-times.log'

vim.api.nvim_create_autocmd('VimEnter', {
  group = vim.api.nvim_create_augroup('startup-profile', { clear = true }),
  callback = function()
    if not (vim.g.__startup_hrtime and uv and uv.hrtime) then
      return
    end
    local start_hrtime = vim.g.__startup_hrtime
    if not start_hrtime then
      return
    end
    local elapsed_ms = (uv.hrtime() - start_hrtime) / 1e6
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local argv = table.concat(vim.v.argv or {}, ' ')
    local line = string.format('%s\t%.2f ms\t%s', timestamp, elapsed_ms, argv)
    if vim.fn.filereadable(log_path) == 0 then
      vim.fn.writefile({}, log_path)
    end
    vim.fn.writefile({ line }, log_path, 'a')
    -- vim.notify(string.format('startup %.2f ms', elapsed_ms))
  end,
})
