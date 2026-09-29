-- Headless verification for lua/xmltag.lua (insert-mode tag auto-close +
-- visual `sat` tag wrap). Not a mini.test suite -- this repo's existing
-- tests/ (zellij_run_test.lua) use plain assert()/print(), so this follows
-- the same convention: one function per case, PASS/FAIL printed per case,
-- `:cq` (non-zero exit) if anything failed.
--
-- Two headless-environment quirks this file works around (neither is a bug
-- in xmltag.lua -- verified independently against plain `:startinsert` and
-- bare `nvim_feedkeys` with no xmltag involved at all):
--   1. `later()`-deferred setup (mini.surround et al.) runs via `vim.schedule`,
--      which never fires while still inside the startup `-c`/`-l` sequence.
--      A `vim.wait()` up front pumps the loop once so it actually runs.
--   2. `nvim_feedkeys(keys, 'x', ...)` behaves like `:normal!`: it always
--      settles back to Normal mode once the given keys are consumed, even if
--      those keys would leave a real interactive session sitting in Insert
--      mode. So each scenario's keys (selection + trigger + typed name +
--      <Esc>) are fed as ONE `feedkeys` call -- consistent with the fact
--      that mid-sequence behavior (did `>` expand correctly, did typed text
--      land as buffer content rather than being reinterpreted as Normal-mode
--      commands) is what's actually observable, not the mode() value after
--      the call returns.
--
-- Run: nvim --headless -u ~/.config/nvim/init.lua -c 'luafile tests/xmltag_spec.lua'

vim.wait(300) -- flush later()-scheduled plugin setup (mini.surround, etc.)

local results = {}
local function check(name, cond, detail)
  table.insert(results, { name = name, ok = cond, detail = detail })
  local line = (cond and 'PASS' or 'FAIL') .. ': ' .. name
  if not cond and detail then line = line .. '\n  ' .. detail end
  print(line)
end

-- Raw literal keys (no <...> key-notation expansion -- exactly what a user
-- typing '<rules>' would send; only use replace_termcodes for actual special
-- keys like <Esc>), fed as one 'x' (execute-until-consumed) batch per case.
local ESC = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
local function feed(keys)
  vim.api.nvim_feedkeys(keys, 'x', false)
end

local function new_buf(ft, lines, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, opts.scratch or false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)
  vim.bo[buf].filetype = ft -- fires FileType synchronously -> our autocmd attaches
  return buf
end

local function get_lines(buf) return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
local function dump(lines) return '[' .. table.concat(lines, '|') .. ']' end

-- 1. markdown: typing `<rules>` on an empty line -> block, content line
-- flush, cursor on middle line, mode `i`. Typing 'hi' right after the '>'
-- (same feedkeys batch, no explicit mode-entering key in between) and
-- finding it on the middle line is the observable proof of "stayed in
-- insert mode on the middle line" (see quirk #2 above: mode() itself can't
-- be checked after the batch returns).
local function test_1(ft, label, tag)
  local buf = new_buf(ft, { '' })
  feed('i<' .. tag .. '>hi')
  local l = get_lines(buf)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local ok = #l == 3 and l[1] == '<' .. tag .. '>' and l[2] == 'hi' and l[3] == '</' .. tag .. '>' and row == 2
  check(label, ok, dump(l) .. ' cursor_row=' .. row)
  feed(ESC)
end

-- 2. markdown: `text <b>` mid-line -> `text <b></b>` with cursor between.
-- Checked via the characters straddling the cursor rather than an exact
-- column: leaving Insert mode moves the cursor left by one (standard Vim
-- behavior), so the *value* nvim_win_get_cursor reports once the driving
-- feedkeys('x') batch has returned is off by one from the true mid-insert
-- position -- but the cursor should always land ON the tag's '>' with '<' of
-- the closing tag immediately after, regardless of that shift.
local function test_2()
  local buf = new_buf('markdown', { '' })
  feed('itext <b>')
  local l = get_lines(buf)
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local ok = l[1] == 'text <b></b>' and l[1]:sub(col + 1, col + 3) == '></'
  check('2 inline mid-line <b>', ok, dump(l) .. ' col=' .. col)
  feed(ESC)
end

-- 3. No auto-close: `a > b`, `->`, `</x>`, `<br/>`, `<` inside a fence.
local function test_3()
  do
    local buf = new_buf('markdown', { '' })
    feed('ia > b')
    check('3a "a > b" untouched', get_lines(buf)[1] == 'a > b', dump(get_lines(buf)))
    feed(ESC)
  end
  do
    local buf = new_buf('markdown', { '' })
    feed('i->')
    check('3b "->" untouched', get_lines(buf)[1] == '->', dump(get_lines(buf)))
    feed(ESC)
  end
  do
    local buf = new_buf('markdown', { '' })
    feed('i</x>')
    check('3c "</x>" untouched', get_lines(buf)[1] == '</x>', dump(get_lines(buf)))
    feed(ESC)
  end
  do
    local buf = new_buf('markdown', { '' })
    feed('i<br/>')
    check('3d "<br/>" untouched', get_lines(buf)[1] == '<br/>', dump(get_lines(buf)))
    feed(ESC)
  end
  do
    local buf = new_buf('markdown', { '```', '', '```' })
    vim.treesitter.get_parser(buf, 'markdown'):parse()
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    feed('i<div>')
    local l = get_lines(buf)
    check('3e "<" inside fence untouched', #l == 3 and l[2] == '<div>', dump(l))
    feed(ESC)
  end
end

-- 4. xml: block case indents the middle line by shiftwidth.
local function test_4()
  local buf = new_buf('xml', { '' })
  local sw = vim.api.nvim_buf_call(buf, function() return vim.fn.shiftwidth() end)
  feed('i<config>')
  local l = get_lines(buf)
  local ok = #l == 3 and l[1] == '<config>' and l[2] == string.rep(' ', sw) and l[3] == '</config>'
  check('4 xml block indents middle line', ok, dump(l) .. ' sw=' .. sw)
  feed(ESC)
end

-- 5. markdown/promptmd: V over 2 lines + sat + `doc id="1"` + <Esc> ->
-- `<doc id="1">`, the 2 lines unchanged and flush, `</doc>`.
local function test_5(buf, label, base_line)
  vim.api.nvim_win_set_cursor(0, { base_line, 0 })
  feed('Vj' .. 'sat' .. 'doc id="1"' .. ESC)
  local l = vim.api.nvim_buf_get_lines(buf, base_line - 1, base_line + 3, false)
  local ok = #l == 4 and l[1] == '<doc id="1">' and l[4] == '</doc>'
  check(label, ok, dump(l))
end

-- 6. xml linewise sat -> content indented one level.
local function test_6()
  local buf = new_buf('xml', { 'value' })
  local sw_str = string.rep(' ', vim.api.nvim_buf_call(buf, function() return vim.fn.shiftwidth() end))
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  feed('V' .. 'sat' .. 'item' .. ESC)
  local l = get_lines(buf)
  local ok = #l == 3 and l[1] == '<item>' and l[2] == (sw_str .. 'value') and l[3] == '</item>'
  check('6 xml linewise sat indents content', ok, dump(l))
end

-- 7. charwise inline sat on one word -> `<em>word</em>` after typing `em`.
local function test_7()
  local buf = new_buf('markdown', { 'word' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  feed('ve' .. 'sat' .. 'em' .. ESC)
  check('7 charwise inline sat', get_lines(buf)[1] == '<em>word</em>', dump(get_lines(buf)))
end

-- 8. sat then <Esc> with an empty name -> buffer identical to the original.
local function test_8()
  local buf = new_buf('markdown', { 'word' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  feed('ve' .. 'sat' .. ESC)
  check('8 empty-name sat reverts', get_lines(buf)[1] == 'word', dump(get_lines(buf)))
end

-- 9. `sa)` in visual still wraps with parens via mini.surround.
local function test_9()
  local buf = new_buf('markdown', { 'word' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  feed('ve' .. 'sa)')
  check('9 sa) still reaches mini.surround', get_lines(buf)[1] == '(word)', dump(get_lines(buf)))
end

-- 10. buftype=nofile buffer: no xmltag maps.
local function test_10()
  local buf = new_buf('markdown', { 'x' }, { scratch = true })
  local has_gt, has_sat = false, false
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, 'i')) do
    if m.lhs == '>' then has_gt = true end
  end
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, 'x')) do
    if m.lhs == 'sat' then has_sat = true end
  end
  check('10 nofile buffer gets no maps', not has_gt and not has_sat,
    'buftype=' .. vim.bo[buf].buftype .. ' has_gt=' .. tostring(has_gt) .. ' has_sat=' .. tostring(has_sat))
end

-- promptmd variants of cases 1 and 5, on a real copy of /tmp/ps_probe.md so
-- ftdetect (plugin/15_filetypes.lua) and the real promptmd parser are both
-- genuinely exercised, not just a buffer with filetype force-set.
local function promptmd_buf()
  local tmp = vim.fn.tempname() .. '.md'
  vim.fn.writefile(vim.fn.readfile('/tmp/ps_probe.md'), tmp)
  vim.cmd('edit ' .. vim.fn.fnameescape(tmp))
  return vim.api.nvim_get_current_buf()
end

local function test_1_promptmd()
  local buf = promptmd_buf()
  if vim.bo[buf].filetype ~= 'markdown.promptmd' then
    check('1p ftdetect sanity', false, 'filetype=' .. vim.bo[buf].filetype)
    return
  end
  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, last, last, false, { '' })
  vim.api.nvim_win_set_cursor(0, { last + 1, 0 })
  feed('i<newsec>hi')
  local l = vim.api.nvim_buf_get_lines(buf, last, last + 3, false)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local ok = #l == 3 and l[1] == '<newsec>' and l[2] == 'hi' and l[3] == '</newsec>' and row == last + 2
  check('1p promptmd block on empty line', ok, dump(l) .. ' cursor_row=' .. row)
  feed(ESC)
end

local function test_5_promptmd()
  local buf = promptmd_buf()
  if vim.bo[buf].filetype ~= 'markdown.promptmd' then
    check('5p ftdetect sanity', false, 'filetype=' .. vim.bo[buf].filetype)
    return
  end
  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, last, last, false, { 'alpha', 'beta' })
  test_5(buf, '5p promptmd V + sat', last + 1)
end

test_1('markdown', '1 markdown block on empty line', 'rules')
test_2()
test_3()
test_4()
do
  local buf = new_buf('markdown', { 'alpha', 'beta' })
  test_5(buf, '5 markdown V + sat', 1)
end
test_6()
test_7()
test_8()
test_9()
test_10()
test_1_promptmd()
test_5_promptmd()

local failed = 0
for _, r in ipairs(results) do
  if not r.ok then failed = failed + 1 end
end
print(string.format('\n%d/%d passed', #results - failed, #results))
if failed > 0 then
  vim.cmd('cq')
else
  vim.cmd('qa!')
end
