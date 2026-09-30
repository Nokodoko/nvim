-- Tests for the <Leader>as history collection in lua/claude_prompt/init.lua.
-- Run with: nvim --headless -c "luafile tests/test_history_picker.lua" -c "qa!"
--
-- Builds a synthetic ~/.icarus/sessions tree: one long "current" session with
-- more assistant replies than the limit, plus two older sessions, and checks
-- that the picker gets the NEWEST replies across sessions, newest first.

local passed, failed = 0, 0
local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then passed = passed + 1; print('PASS: ' .. name)
  else failed = failed + 1; print('FAIL: ' .. name .. '\n      ' .. tostring(err)) end
end
local function eq(got, want, what)
  if not vim.deep_equal(got, want) then
    error(string.format('%s:\n  expected %s\n  got      %s', what, vim.inspect(want), vim.inspect(got)), 2)
  end
end

local cp = require('claude_prompt')
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/proj/usage', 'p')

--- Write a session file with `n` user/assistant pairs; reply i is "S<tag> reply i".
--- `t0` is the epoch second of the first record; `mtime` sets the file's mtime.
local function session(name, tag, n, t0, mtime)
  local path = string.format('%s/proj/%s.jsonl', root, name)
  local lines = { '{"type":"session_start","ts":"' .. os.date('!%Y-%m-%dT%H:%M:%SZ', t0) .. '"}' }
  for i = 1, n do
    local ts = os.date('!%Y-%m-%dT%H:%M:%SZ', t0 + i * 60)
    lines[#lines + 1] = string.format('{"type":"user_message","ts":"%s","text":"ask %d"}', ts, i)
    lines[#lines + 1] = string.format('{"type":"assistant_message","ts":"%s","text":"%s reply %d\\nsecond line with needle-%s-%d"}', ts, tag, i, tag, i)
  end
  vim.fn.writefile(lines, path)
  vim.uv.fs_utime(path, mtime, mtime)
  return path
end

-- A token-accounting file that must be ignored.
vim.fn.writefile({ '{"type":"assistant_message","ts":"2026-01-01T00:00:00Z","text":"USAGE must not appear"}' }, root .. '/proj/usage/x.jsonl')

local base = 1700000000
session('old', 'OLD', 5, base, base + 1000)          -- oldest
session('mid', 'MID', 5, base + 10000, base + 11000)  -- middle
session('cur', 'CUR', 40, base + 20000, base + 30000) -- current, longer than the limit

cp.icarus_sessions_dir = root

check('session files are newest-first and skip usage/', function()
  local files = cp._get_icarus_session_files()
  local names = vim.tbl_map(function(p) return vim.fn.fnamemodify(p, ':t:r') end, files)
  eq(names, { 'cur', 'mid', 'old' }, 'file order')
end)

check('limit smaller than the current session returns its NEWEST replies', function()
  local entries = cp._collect_icarus_entries(cp._get_icarus_session_files(), 'assistant_message', 10)
  eq(#entries, 10, 'count')
  eq(entries[1].text:match('^CUR reply (%d+)'), '40', 'first entry is the latest reply')
  eq(entries[10].text:match('^CUR reply (%d+)'), '31', 'tenth entry is the tenth-latest')
end)

check('limit spanning sessions walks back newest-first, sorted by time', function()
  local entries = cp._collect_icarus_entries(cp._get_icarus_session_files(), 'assistant_message', 43)
  eq(#entries, 43, 'count')
  eq(entries[1].text:sub(1, 12), 'CUR reply 40', 'newest')
  eq(entries[41].text:sub(1, 11), 'MID reply 5', 'after the current session comes the middle one')
  eq(entries[43].text:sub(1, 11), 'MID reply 3', 'still middle; old session not reached')
  for i = 2, #entries do
    assert(entries[i - 1].timestamp >= entries[i].timestamp, 'entries are newest-first at index ' .. i)
  end
end)

check('usage/ files never contribute', function()
  local entries = cp._collect_icarus_entries(cp._get_icarus_session_files(), 'assistant_message', 1000)
  for _, e in ipairs(entries) do assert(not e.text:find('USAGE'), 'usage entry leaked') end
  eq(#entries, 50, 'all real replies')
end)

check('entries carry the whole text (what the picker fuzzy-matches on)', function()
  local entries = cp._collect_icarus_entries(cp._get_icarus_session_files(), 'assistant_message', 1)
  assert(entries[1].text:find('needle-CUR-40', 1, true), 'second line of the reply is present')
  eq(entries[1].session, 'cur', 'session tag')
end)

check('preview jumps to the line that best matches the prompt', function()
  local lines = { '# heading', 'prose about tags', '', '<decision_needed>', 'more text', 'decide something' }
  eq(cp.find_best_line(lines, 'decision_needed'), 4, 'exact substring wins')
  eq(cp.find_best_line(lines, 'DECISION'), 4, 'case-insensitive')
  eq(cp.find_best_line(lines, 'dcsn'), 4, 'fuzzy: most prompt chars in order')
  eq(cp.find_best_line(lines, ''), nil, 'empty prompt: stay at top')
  eq(cp.find_best_line(lines, 'zzzz'), nil, 'no char matches at all: stay at top')
end)

vim.fn.delete(root, 'rf')
print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
