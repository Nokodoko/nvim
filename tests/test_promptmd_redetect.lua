-- Regression test: a plain markdown buffer that gains tag sections after it
-- was opened is promoted to markdown.promptmd on InsertLeave / write.
-- Run with: nvim --headless -c "luafile tests/test_promptmd_redetect.lua" -c "qa!"

local passed, failed = 0, 0
local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print('PASS: ' .. name)
  else failed = failed + 1; print('FAIL: ' .. name .. '\n      ' .. tostring(err)) end
end
local function eq(got, want, what)
  if got ~= want then error(string.format('%s: expected %s, got %s', what, vim.inspect(want), vim.inspect(got)), 2) end
end

vim.wait(1500, function() return false end) -- deferred plugin setup

local tmp = vim.fn.tempname() .. '.md'

check('new empty .md opens as plain markdown', function()
  vim.cmd('edit ' .. vim.fn.fnameescape(tmp))
  eq(vim.bo.filetype, 'markdown', 'filetype')
end)

check('typing a tag section then leaving Insert promotes to markdown.promptmd', function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<testing>', '# TESTING', '    some **bold** prose', '</testing>' })
  vim.cmd('normal! A ') -- enter and leave Insert => InsertLeave fires
  eq(vim.bo.filetype, 'markdown.promptmd', 'filetype after InsertLeave')
  vim.treesitter.get_parser(0):parse(true)
  local caps = {}
  for _, c in ipairs(vim.treesitter.get_captures_at_pos(0, 1, 2)) do caps[c.capture] = true end
  assert(caps['markup.heading.1'], 'heading is highlighted as markdown after promotion')
end)

check('a promptmd buffer is left alone (no flapping back to markdown)', function()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'just prose now' })
  vim.cmd('normal! A ')
  eq(vim.bo.filetype, 'markdown.promptmd', 'filetype stays')
end)

check('write also promotes', function()
  local tmp2 = vim.fn.tempname() .. '.md'
  vim.cmd('edit ' .. vim.fn.fnameescape(tmp2))
  eq(vim.bo.filetype, 'markdown', 'fresh buffer')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '<rules>', '- one', '</rules>' })
  vim.cmd('write')
  eq(vim.bo.filetype, 'markdown.promptmd', 'filetype after write')
  vim.fn.delete(tmp2)
end)

vim.fn.delete(tmp)
print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
