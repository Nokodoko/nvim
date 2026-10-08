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

-- Mechanism C: `<Right>` in ANY visual mode runs the `sat` tag wrap. Driven with
-- feedkeys(..., 'tx'): 't' expands termcodes and, crucially, the ABSENCE of 'm'
-- leaves remapping ON, so `<Right>` is looked up in the mapping table exactly as
-- a real keypress would be (verified against a real pty). Each of the three
-- visual modes -- char `v`, line `V`, block `Ctrl-V` -- must start the naming
-- session; NORMAL-mode `<Right>` must stay native.

check('setup_buffer installs an x-mode <expr> <Right> mapping', function()
  local buf = markdown_buf({ 'text' })
  local found
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, 'x')) do
    if m.lhs == '<Right>' then found = m end
  end
  if not found then error('no x-mode <Right> mapping installed') end
  if found.expr ~= 1 then error('mapping is not <expr>') end
end)

--- Leave any live naming session and drain until normal mode is STABLE.
--- Mechanism B's reformat calls `startinsert` from a `vim.schedule`, which can
--- land AFTER a naive `mode()=='n'` check -- so a single poll sees normal mode,
--- then the queued `startinsert` fires and the next trial's keys get typed as
--- text. Poll until 'n' holds across consecutive checks before returning.
local function drain_to_normal(buf)
  for _ = 1, 10 do
    vim.api.nvim_feedkeys('\27', 'nt', false)
    vim.wait(120, function() return false end)
    if vim.fn.mode() == 'n' and vim.b[buf].xml_surround_pending == nil then
      vim.wait(120, function() return false end)
      if vim.fn.mode() == 'n' then return end
    end
  end
end

--- Select with `select_keys`, press a real `<Right>`, expect the naming session.
--- Fully drains (see drain_to_normal) so the next test starts from a settled
--- normal-mode state.
local function right_arrow_wraps(label, select_keys)
  local buf = markdown_buf({ 'aaa111', 'bbb222', 'ccc333' })
  vim.api.nvim_win_set_cursor(0, { 1, 3 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(select_keys .. '<Right>', true, false, true), 'tx', false)
  vim.wait(1000, function() return vim.b[buf].xml_surround_pending == true end)
  if not vim.b[buf].xml_surround_pending then error(label .. ' <Right> never started the naming session') end
  drain_to_normal(buf)
end

check('<Right> in visual-BLOCK starts the naming session', function()
  right_arrow_wraps('block', '<C-V>jj2l')
end)

check('<Right> in visual-CHAR starts the naming session', function()
  right_arrow_wraps('char', 'viw')
end)

check('<Right> in visual-LINE starts the naming session', function()
  right_arrow_wraps('line', 'V')
end)

check('<Right> in NORMAL mode is untouched by the binding', function()
  local buf = markdown_buf({ 'hello world' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Right><Right>', true, false, true), 'tx', false)
  -- Wait for the fed keys to be consumed (they move the cursor natively to col 2).
  vim.wait(500, function() return vim.api.nvim_win_get_cursor(0)[2] == 2 end)
  if vim.b[buf].xml_surround_pending then error('normal-mode <Right> wrongly started a wrap') end
  local col = vim.api.nvim_win_get_cursor(0)[2]
  if col ~= 2 then error('normal-mode <Right> did not move natively, col=' .. col) end
end)

print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
