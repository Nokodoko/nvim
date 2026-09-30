-- Tests for lua/xml_surround.lua Mechanism B (visual `sat`).
-- Run with: nvim --headless -c "luafile tests/test_xml_surround.lua" -c "qa!"
--
-- Drives the real mini.surround mapping through `:normal` (mini reads the
-- surrounding id from :normal's typeahead), lets the scheduled reformat run
-- via vim.wait, then names the tag with `:normal! i...` -- leaving Insert
-- there fires the InsertLeave that mirrors the name and adds the h1 line.

local passed, failed = 0, 0

local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print('PASS: ' .. name)
  else
    failed = failed + 1
    print('FAIL: ' .. name .. '\n      ' .. tostring(err))
  end
end

local function eq(got, want, what)
  if not vim.deep_equal(got, want) then
    error(string.format('%s:\n  expected %s\n  got      %s', what or 'value', vim.inspect(want), vim.inspect(got)), 2)
  end
end

-- Deferred plugin setup (MiniDeps.later) must have landed before mini.surround
-- mappings exist.
vim.wait(1500, function() return false end)

local function markdown_buf(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  return buf
end

--- Select with `select_keys` from (row, col), run `sat`, wait for the naming
--- session, type `typed`, leave Insert, wait for teardown; return the lines.
local function run_sat(buf, row, col, select_keys, typed)
  vim.api.nvim_win_set_cursor(0, { row, col })
  vim.cmd('normal ' .. select_keys .. 'sat')
  vim.wait(500, function() return vim.b[buf].xml_surround_pending == true end)
  if not vim.b[buf].xml_surround_pending then error('naming session never started') end
  vim.cmd('normal! i' .. typed)
  vim.wait(500, function() return vim.b[buf].xml_surround_pending == nil end)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

check('linewise V selection: tag pair, upper-cased h1 copy, indented body', function()
  local buf = markdown_buf({ 'intro', '    some selected text', 'outro' })
  eq(run_sat(buf, 2, 0, 'V', 'rules id="1"'), {
    'intro',
    '    <rules id="1">',
    '    # RULES ID="1"',
    '        some selected text',
    '    </rules>',
    'outro',
  })
end)

check('charwise v selection of a whole line', function()
  local buf = markdown_buf({ 'some selected text' })
  eq(run_sat(buf, 1, 0, 'v$h', 'note'), {
    '<note>',
    '# NOTE',
    '    some selected text',
    '</note>',
  })
end)

check('plain <Esc> with nothing typed leaves empty markers and no h1', function()
  local buf = markdown_buf({ 'text' })
  eq(run_sat(buf, 1, 0, 'V', ''), { '<>', '    text', '</>' })
end)

print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
