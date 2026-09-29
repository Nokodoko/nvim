-- Tests for lua/chunked.lua
-- Run with: nvim --headless -c "luafile tests/test_chunked.lua" -c "qa!"
--
-- These assert the structural claims the module is built on, using the real
-- promptmd grammar (parser at ~/.local/share/nvim/site/parser/promptmd.so)
-- rather than fixtures -- if the grammar or the injection changes, these fail.

local chunked = require('chunked')

local passed, failed = 0, 0

--- Build a scratch buffer of the given lines as promptmd and return its number.
local function promptmd_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown.promptmd'
  vim.treesitter.start(buf, 'promptmd')
  return buf
end

--- Run analyze() with a target and return (chunks, summary).
local function run(lines, target)
  local buf = promptmd_buf(lines)
  chunked.setup({ target_tokens = target or 4000, stripe = false, virt_text = false })
  local chunks, summary = chunked.analyze(buf)
  return chunks, summary, buf
end

--- Flatten chunk unit rows into "start-end" strings for comparison.
local function spans(chunks)
  local out = {}
  for _, c in ipairs(chunks) do
    out[#out + 1] = string.format('%d-%d', c.units[1].start_row, c.units[#c.units].end_row)
  end
  return table.concat(out, ' ')
end

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
  if got ~= want then
    error(string.format('%s: expected %s, got %s', what or 'value', vim.inspect(want), vim.inspect(got)), 2)
  end
end

-- ---------------------------------------------------------------- structure --

check('nested element is not reported as unclosed', function()
  -- The draft's single `inside_xml_tag` boolean reported the OUTER tag closed
  -- as soon as the INNER one closed. With nesting, neither is a hazard.
  local chunks = run({
    '<outer>',
    '  <inner>',
    '  body',
    '  </inner>',
    'between',
    '</outer>',
  })
  eq(#chunks, 1, 'chunk count')
  eq(chunks[1].units[1].hazard, nil, 'hazard on a properly nested element')
end)

check('unclosed element is an unclosed hazard', function()
  local chunks = run({ '<rules>', 'body text', 'more body' })
  local h = chunks[1].units[1].hazard
  assert(h, 'expected a hazard')
  eq(h.kind, 'unclosed', 'hazard kind')
  eq(h.name, 'rules', 'hazard tag name')
end)

check('mismatched end tag is a mismatch hazard', function()
  local chunks = run({ '<wrong>', 'body', '</WRONG>' })
  local h = chunks[1].units[1].hazard
  assert(h, 'expected a hazard')
  eq(h.kind, 'mismatched', 'hazard kind')
end)

check('self-closing tag is not a hazard', function()
  local chunks = run({ '<meta kind="x"/>', 'text after' })
  eq(chunks[1].units[1].hazard, nil, 'hazard on self-closing tag')
end)

-- -------------------------------------------------------------------- prose --

check('prose mention of a tag is not a tag', function()
  -- The draft matched `<document` anywhere in a line, so this prose line read
  -- as an open tag and poisoned every chunk after it.
  local chunks = run({
    'Use the <document> tag for each file.',
    'Another prose line mentioning <rules> inline.',
  })
  eq(#chunks, 1, 'chunk count')
  eq(chunks[1].units[1].hazard, nil, 'hazard from prose tag mention')
end)

check('tag-looking line inside a fence is not a tag', function()
  local chunks = run({
    '```',
    '<fenced>',
    'not a real tag',
    '```',
    'plain text after the fence',
  })
  eq(chunks[1].units[1].hazard, nil, 'hazard from fenced tag look-alike')
end)

-- ------------------------------------------------------------------- packing --

check('no chunk exceeds the target unless it holds one oversized unit', function()
  -- This is the invariant the greedy packer must hold; the first draft
  -- silently exceeded the target when it held out for a heading boundary.
  local target = 40
  local lines = {}
  for i = 1, 60 do lines[#lines + 1] = string.format('<sect%d>', i) end
  for i = 1, 60 do
    lines[#lines + 1] = string.rep('x', 30)
    lines[#lines + 1] = string.format('</sect%d>', i)
  end
  local chunks = run(lines, target)
  for i, c in ipairs(chunks) do
    if c.tokens > target then
      assert(c.oversized,
        string.format('chunk %d is %.0f tokens (> %d) but not flagged oversized', i, c.tokens, target))
      eq(#c.units, 1, 'oversized chunk must hold exactly one unit')
    end
  end
end)

check('units are packed in document order with no gaps or overlaps', function()
  local chunks = run({
    'preamble text',
    '<a>', 'a body', '</a>',
    '<b>', 'b body', '</b>',
    'trailing text',
  }, 30)
  local prev_end = -1
  for i, c in ipairs(chunks) do
    local s, e = c.units[1].start_row, c.units[#c.units].end_row
    assert(s >= prev_end, string.format('chunk %d starts at %d, before previous end %d', i, s, prev_end))
    assert(e >= s, string.format('chunk %d ends before it starts', i))
    prev_end = e
  end
end)

check('leading content is not flagged as an unclosed tag', function()
  -- Content before the first tag is a unit of its own; it must not inherit a
  -- hazard from the classification default.
  local chunks = run({ 'preamble before any tag', 'more preamble', '<a>', 'body', '</a>' })
  eq(chunks[1].units[1].hazard, nil, 'hazard on leading content')
end)

check('trailing content attaches to the preceding unit', function()
  -- Otherwise the trailing text floats to the head of the next chunk and the
  -- boundary lands between a close tag and the text that belongs to it.
  local chunks = run({ '<a>', 'body', '</a>', 'trailing note' }, 4000)
  eq(#chunks, 1, 'chunk count')
  eq(chunks[1].units[#chunks[1].units].end_row, 3, 'last unit covers the trailing line')
end)

-- ----------------------------------------------------------------- oversized --

check('oversized element reports nested headings as split suggestions', function()
  -- Headings in promptmd live INSIDE elements, so they cannot be used as
  -- automatic cut points; they are reported instead.
  local lines = { '<body>' }
  for _, h in ipairs({ 'Alpha', 'Beta', 'Gamma' }) do
    lines[#lines + 1] = '## ' .. h
    for i = 1, 10 do lines[#lines + 1] = h .. ' body text line ' .. i end
  end
  lines[#lines + 1] = '</body>'
  local chunks = run(lines, 40)
  local oversized
  for _, c in ipairs(chunks) do
    if c.oversized then oversized = c end
  end
  assert(oversized, 'expected an oversized chunk')
  eq(#oversized.units, 1, 'oversized chunk holds one unit')
  local rows = oversized.units[1].split_rows
  assert(rows and #rows == 3,
    'expected 3 nested heading rows as split suggestions, got ' .. tostring(rows and #rows))
end)

-- --------------------------------------------------------------- token math --

check('token estimate counts display cells, not bytes', function()
  -- A CJK character is 1 codepoint, 3 bytes, 2 display cells. Byte counting
  -- over-reports it 3x: this buffer is 23 cells but 31 bytes.
  local buf = promptmd_buf({ '<c>', '中文字符测试内容', '</c>' })
  chunked.setup({ target_tokens = 4000, stripe = false, virt_text = false })
  local chunks = chunked.analyze(buf)
  eq(vim.api.nvim_strwidth('中文字符测试内容'), 16, 'strwidth of the CJK line')
  -- cells: 3 + 16 + 4 = 23, / chars_per_token 4
  eq(chunks[1].tokens, 23 / 4, 'tokens from cell count')
end)

-- ------------------------------------------------------------------ fallback --

check('plain markdown without tag structure yields one unit', function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '# Title', '', 'just prose, no tags at all' })
  vim.bo[buf].filetype = 'markdown'
  chunked.setup({ target_tokens = 4000, stripe = false, virt_text = false })
  local chunks, summary = chunked.analyze(buf)
  eq(#chunks, 1, 'chunk count')
  eq(summary.hazards, 0, 'hazards')
end)

-- --------------------------------------------------------------- idempotency --

check('analyze twice does not accumulate extmarks', function()
  local buf = promptmd_buf({ '<a>', 'body', '</a>', '<b>', 'body', '</b>' })
  chunked.setup({ target_tokens = 4000, stripe = true, virt_text = true })
  chunked.analyze(buf)
  local first = #vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace('chunked'), 0, -1, {})
  chunked.analyze(buf)
  local second = #vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace('chunked'), 0, -1, {})
  eq(second, first, 'extmark count after re-analyze')
end)

check('clear removes all chunked extmarks', function()
  local buf = promptmd_buf({ '<a>', 'body', '</a>' })
  chunked.setup({ target_tokens = 4000, stripe = true, virt_text = true })
  chunked.analyze(buf)
  chunked.clear(buf)
  local n = #vim.api.nvim_buf_get_extmarks(buf, vim.api.nvim_create_namespace('chunked'), 0, -1, {})
  eq(n, 0, 'extmark count after clear')
end)

-- ---------------------------------------------------------------- debounce --

check('pending refresh is per-buffer (no cross-buffer cancellation)', function()
  -- The debounce timer used to be one module-level handle: editing buffer B
  -- inside A's window called stop() on the callback naming A, so A's overlay
  -- went stale forever. Count analyze() calls per buffer instead of looking
  -- at marks, so the assertion is about scheduling, not rendering.
  local bufA = promptmd_buf({ '<a>', 'body a', '</a>' })
  local bufB = promptmd_buf({ '<b>', 'body b', '</b>' })
  chunked.setup({ target_tokens = 4000, stripe = false, virt_text = false, refresh_on_edit = 120 })

  local refreshed = {}
  local real_analyze = chunked.analyze
  chunked.analyze = function(b, ...)
    refreshed[b] = (refreshed[b] or 0) + 1
    return real_analyze(b, ...)
  end

  local ok, err = pcall(function()
    vim.b[bufA].chunked_enabled = true
    vim.b[bufB].chunked_enabled = true
    -- Interleave: A, B, A -- all within one debounce window per buffer.
    vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufA })
    vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufB })
    vim.api.nvim_exec_autocmds('TextChanged', { buffer = bufA })
    -- Nothing may fire inside the window.
    eq(refreshed[bufA], nil, 'A refreshed inside the debounce window')
    vim.wait(400)
    assert(refreshed[bufA] and refreshed[bufA] >= 1, 'A was never refreshed (cross-buffer cancellation)')
    assert(refreshed[bufB] and refreshed[bufB] >= 1, 'B was never refreshed')
  end)
  chunked.analyze = real_analyze
  if not ok then error(err) end
end)

check('disable cancels a pending refresh', function()
  local buf = promptmd_buf({ '<a>', 'body', '</a>' })
  chunked.setup({ target_tokens = 4000, stripe = false, virt_text = false, refresh_on_edit = 120 })
  vim.b[buf].chunked_enabled = true

  local calls = 0
  local real_analyze = chunked.analyze
  chunked.analyze = function(...) calls = calls + 1; return real_analyze(...) end
  local ok, err = pcall(function()
    vim.api.nvim_exec_autocmds('TextChanged', { buffer = buf })
    chunked.disable(buf)
    vim.wait(400)
    eq(calls, 0, 'analyze ran after disable')
  end)
  chunked.analyze = real_analyze
  if not ok then error(err) end
end)

-- --------------------------------------------------------------------- report --

print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
