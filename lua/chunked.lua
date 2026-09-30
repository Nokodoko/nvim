-- Attention-aware chunk visualizer for promptmd / markdown buffers.
--
-- Splits the buffer into the chunks a context builder would emit and draws the
-- result in place: zebra-striped chunk backgrounds, a marker per boundary, and
-- warnings where structure cannot fit the target.
--
-- WHY TREESITTER AND NOT LINE SCANNING
-- ------------------------------------
-- This repo ships a promptmd grammar (~/Programs/tree-sitter-promptmd, built
-- to ~/.local/share/nvim/site/parser/promptmd.so) whose `element` nodes NEST,
-- and whose markdown injection (queries/promptmd/injections.scm) parses the
-- text between tag lines as real markdown. That gives three things a line
-- regex cannot:
--
--   1. Nesting. A `<section>` inside `<context>` is a distinct node, so "am I
--      inside an open tag" is a stack, not a boolean -- a boolean reports the
--      outer tag as closed the moment the inner one closes.
--   2. Tag lines vs prose. `use the <document> tag here` is prose, and a
--      tag-looking line inside a ``` fence is not a tag. The grammar already
--      decides both; re-deriving it per line is where regex goes wrong.
--   3. Closed / mismatched / unclosed are three distinct structural facts
--      (`end_tag` child / `erroneous_end_tag` child / neither), and only the
--      last two are clip hazards.
--
-- Two API details verified against nvim 0.13.0-dev-1738 that are easy to get
-- wrong:
--   * `parser:parse()` does NOT process injections -- `parser:children()`
--     stays empty; `parser:parse(true)` does. Chunking needs only promptmd's
--     own tree, so everything here deliberately passes plain parse(): with
--     the grammar's `injection.combined`, parse(true) re-scans and re-parses
--     the whole injected markdown tree on every edit (measured 40-60 ms on a
--     200-section buffer -- the typing lag this replaced; see
--     heading_rows_scan()).
--   * `node:text()` is unavailable on these nodes; text comes from
--     `vim.treesitter.get_node_text(node, bufnr)`.
--
-- Chunking model
-- --------------
-- Top-level nodes are packed into "units", the smallest thing a boundary may
-- be placed around: each top-level element (whole subtree, tags included) is
-- one unit, and a run of bare top-level content attaches to the unit before it
-- so trailing text never floats to the head of the next chunk. Units are packed
-- greedily, so the invariant is strong and checkable:
--
--   every chunk's token count is <= target, UNLESS a single unit alone
--   exceeds it -- in which case that chunk is flagged `oversized`.
--
-- There is deliberately no "hold out for a better boundary" heuristic. The
-- obvious candidate for one is a markdown heading, but headings in promptmd
-- live INSIDE elements (verified: in a `<body>` block, `## Alpha`/`## Beta` are
-- `content` children of the `element` node), so a heading is never a legal cut
-- under a no-split-element rule. Instead of silently exceeding the target, an
-- oversized element is reported with the heading rows nested inside it as the
-- split suggestions a human should act on.

local M = {}

local ns = vim.api.nvim_create_namespace('chunked')

M.defaults = {
  -- Target chunk size, in estimated tokens.
  target_tokens = 4000,
  -- Token estimate = display cells / chars_per_token. Cells rather than bytes
  -- so double-width text (CJK) is not over-counted 2-3x.
  chars_per_token = 4,
  -- Zebra-stripe each chunk's background.
  stripe = true,
  -- Show the right-aligned boundary/overflow annotations.
  virt_text = true,
  -- Filetypes Chunk acts on (auto-enabled visualization and token count).
  filetypes = { 'markdown', 'markdown.promptmd', 'xml', 'html' },
  -- Re-chunk after edits, debounced by this many milliseconds of idle time.
  -- The refresh itself is incremental and costs well under a millisecond on
  -- an 8k-line buffer, so the debounce is about not repainting extmarks on
  -- every keystroke, not about hiding a slow pass.
  refresh_on_edit = 200,
}

M.config = vim.tbl_extend('force', M.defaults, {})

-- Groups link to standard diagnostic highlights so they follow the active
-- colorscheme; `default = true` preserves any user override.
--
-- The stripe groups are applied via `line_hl_group`, which layers UNDER the
-- syntax/treesitter highlights: any text with no highlight of its own takes
-- the stripe group's foreground. So a stripe group must be background-only.
-- ChunkOdd used to link to NonText (a dim fg, no bg): that painted every
-- unhighlighted line of prose in the odd chunks -- in a plain .md buffer the
-- whole file is chunk 1 -- in the colorscheme's "invisible" text colour.
-- ColorColumn is bg-only in mini.hues (and in every colorscheme that follows
-- the standard highlight semantics).
local hl_spec = {
  ChunkBoundaryIdeal = { link = 'DiagnosticOk', default = true },
  ChunkBoundaryGood = { link = 'DiagnosticHint', default = true },
  ChunkOversized = { link = 'DiagnosticWarn', default = true },
  ChunkClip = { link = 'DiagnosticError', default = true },
  ChunkEven = { default = true },
  ChunkOdd = { link = 'ColorColumn', default = true },
}

function M.define_highlights()
  for group, spec in pairs(hl_spec) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

--- Estimated token count of a string, in display cells / chars_per_token.
local function estimate_tokens(text, chars_per_token)
  return vim.api.nvim_strwidth(text) / chars_per_token
end

--- Is this filetype one Chunk measures?
---
--- Compound filetypes ('markdown.promptmd') match by prefix: the config lists
--- 'markdown' meaning "markdown and anything built on it". Autocmd patterns
--- are NOT split on '.' for compound filetypes (verified), so autocmds use a
--- callback through this function instead of filetype patterns.
function M.is_measured(ft)
  if not ft or ft == '' then return false end
  for _, pattern in ipairs(M.config.filetypes) do
    if ft == pattern or ft:find('^' .. vim.pesc(pattern) .. '%.') then return true end
  end
  return false
end

--- Estimated token count of a whole buffer, memoized on 'changedtick'.
---
--- WHY THIS EXISTS SEPARATELY FROM analyze()
--- -----------------------------------------
--- The statusline calls this on EVERY redraw -- which means on every cursor
--- move, far more often than a keystroke -- while a full pass costs ~1ms on an
--- 8k-line buffer (measured). So the pass happens at most once per edit and is
--- otherwise a table lookup. `changedtick` is bumped by every change to the
--- buffer's text, so it is a sound invalidation key; it is also bumped by some
--- non-text state changes, which only ever costs a redundant recompute, never a
--- stale answer.
---
--- Only the configured filetypes are measured. The number is a prompt-budget
--- figure, so a 100k-line source file must not pay for a scan nobody reads.
---
--- @param bufnr? integer  buffer handle (default: current buffer)
--- @return integer? tokens  nil when this buffer is not measured
function M.token_count(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return nil end

  local ft = vim.bo[bufnr].filetype
  if not M.is_measured(ft) then return nil end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cached = M._token_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.tokens
  end

  local total = 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    total = total + estimate_tokens(line, M.config.chars_per_token)
  end
  local tokens = math.floor(total + 0.5)
  M._token_cache[bufnr] = { tick = tick, tokens = tokens }
  return tokens
end

-- bufnr -> { tick, tokens }. Dropped on BufUnload in setup() so the table does
-- not grow with every file opened in a long-lived session.
M._token_cache = {}

--- The last line a node actually occupies.
---
--- A node that ends at column 0 (every `content` node does, and an `element`
--- ending in `_implicit_end_tag` can) has an exclusive end_row: `content`
--- spanning 2:4-4:0 covers lines 2 and 3, not 4. Using the raw end_row here
--- would count one line too many and paint the stripe one line long.
local function last_row(node)
  local srow, _, erow, ecol = node:range()
  return (ecol == 0 and erow > srow) and (erow - 1) or erow
end

--- The buffer's promptmd document root and parser, or nil when the buffer has
--- no promptmd structure (plain markdown, txt, ...).
---
--- parse() WITHOUT the `true` argument: chunk boundaries derive entirely from
--- promptmd's own tree, and asking for injections (parse(true)) would re-run
--- the combined-markdown injection on every refresh -- measured 40-60 ms per
--- edit on a 200-section buffer, versus ~0.4 ms for the promptmd re-parse
--- alone. (parse() does not process injections; parse(true) does -- verified
--- against nvim 0.13's languagetree.lua, and the reason the old code passed
--- true: it needed the injected markdown tree for headings. That need is
--- gone: heading rows come from heading_rows_scan() now.)
local function promptmd_root(bufnr)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'promptmd')
  if not ok or not parser then return nil end
  local ok2, trees = pcall(function() return parser:parse() end)
  if not ok2 or not trees or not trees[1] then return nil end
  local root = trees[1]:root()
  if not root or root:type() ~= 'document' then return nil end
  return root, parser
end

--- Structural facts about one top-level node that decide whether cutting
--- around it is safe.
---   closed     -- element ends in a real `end_tag`
---   mismatched -- ends in `erroneous_end_tag` (close name != open name)
---   neither    -- closed by the grammar's `_implicit_end_tag`: still open
local function classify_top_node(node, bufnr)
  local kind = node:type()
  if kind == 'content' then
    return { kind = 'content', closed = true }
  end
  if kind == 'self_closing_tag' then
    local name_node = node:named_child(0)
    return {
      kind = 'self_closing',
      closed = true,
      name = name_node and vim.treesitter.get_node_text(name_node, bufnr) or '?',
    }
  end
  if kind == 'erroneous_end_tag' then
    -- A stray close at top level: nothing it could have closed.
    local tn = node:named_child(0)
    return { kind = 'stray_close', closed = false, name = tn and vim.treesitter.get_node_text(tn, bufnr) or '?' }
  end
  if kind == 'element' then
    local last, name
    for child in node:iter_children() do
      last = child
      if not name and child:type() == 'start_tag' then
        local tn = child:named_child(0)
        name = tn and vim.treesitter.get_node_text(tn, bufnr) or '?'
      end
    end
    local last_type = last and last:type() or nil
    return {
      kind = 'element',
      name = name or '?',
      closed = last_type == 'end_tag',
      mismatched = last_type == 'erroneous_end_tag',
    }
  end
  return { kind = kind, closed = true }
end

--- Fence-aware ATX heading rows, from a line scan.
---
--- WHY A SCAN AND NOT THE INJECTED MARKDOWN TREE
--- ---------------------------------------------
--- The heading rows are only ever used as split suggestions inside an
--- oversized element's warning label -- a hint, not the chunking itself.
--- Getting them from the markdown tree injected into promptmd costs a full
--- `parser:parse(true)`: the promptmd injection sets `injection.combined`
--- (queries/promptmd/injections.scm), which forces a whole-document
--- injection re-scan and invalidates the entire markdown child tree on
--- every edit -- measured 40-60 ms on a 200-section buffer, versus 0.3 ms
--- for this scan. Chunk boundaries and token counts never touch the
--- markdown tree, so paying for it on every keystroke's refresh was the
--- lag. Verified against the treesitter markdown tree on adversarial
--- inputs (fences with info strings, tilde fences, longer-fence nesting,
--- 4-space-indented fences, setext, tag-wrapped content): identical rows.
---
--- The rules that matter, per CommonMark ATX:
---   * 1-6 '#', then EOL or space/tab (so `#hashtag` and `#######` are out)
---   * up to 3 leading spaces (a 4-space indent is indented code)
---   * nothing inside a fenced code block (``` or ~~~, closed by the same
---     char at >= the opening length with nothing else on the line)
local function heading_rows_scan(lines)
  local rows = {}
  local fence_char, fence_len = nil, 0
  for i, line in ipairs(lines) do
    local indent = #(line:match('^ *') or '')
    if indent >= 4 then
      -- Indented code: never a fence opener, never a heading.
    else
      local run = line:match('^ *(`+)') or line:match('^ *(~+)')
      if fence_char then
        if run and run:sub(1, 1) == fence_char and #run >= fence_len
            and line:match('^ *' .. fence_char .. '+ *$') then
          fence_char, fence_len = nil, 0
        end
      elseif run and #run >= 3 then
        fence_char, fence_len = run:sub(1, 1), #run
      elseif line:match('^ ? ? ?#') then
        local hashes = line:match('^ *#+')
        if #hashes <= 6 then
          local after = line:sub(#hashes + 1, #hashes + 1)
          if after == '' or after == ' ' or after == '\t' then
            rows[#rows + 1] = i - 1
          end
        end
      end
    end
  end
  return rows
end

--- Pack the document's top-level nodes into units: the atomic pieces a chunk
--- boundary may be placed between. Each top-level element / self-closing tag /
--- stray close is its own unit carrying its whole subtree; a run of `content`
--- appends to the previous unit, or opens a new one at the start of the buffer.
local function build_units(root, bufnr, lines)
  local units = {}

  for node in root:iter_children() do
    local srow = node:range()
    local erow = last_row(node)
    local info = classify_top_node(node, bufnr)
    local prev = units[#units]

    if info.kind == 'content' and prev then
      -- Attach trailing content to the unit it follows.
      prev.end_row = math.max(prev.end_row, erow)
    else
      units[#units + 1] = {
        start_row = srow,
        end_row = erow,
        tokens = 0,
        kind = info.kind,
        name = info.name,
        -- A hazard is a structural defect, independent of size: an element
        -- with no end tag, or one whose end tag name does not match.
        hazard = (not info.closed) and {
          kind = info.mismatched and 'mismatched' or 'unclosed',
          name = info.name,
        } or nil,
        split_rows = {},
      }
    end
  end

  -- Token weight per unit, from the lines it actually spans.
  for _, unit in ipairs(units) do
    local total = 0
    for row = unit.start_row, math.min(unit.end_row, #lines - 1) do
      total = total + estimate_tokens(lines[row + 1] or '', M.config.chars_per_token)
    end
    unit.tokens = total
  end

  -- Split suggestions via a single merge pass: units are in document order
  -- and rows are sorted, so a moving pointer assigns each heading row to the
  -- unit that strictly contains it (same bounds as the old per-unit filter:
  -- row > start_row and row < end_row).
  local rows = heading_rows_scan(lines)
  local ri = 1
  for _, unit in ipairs(units) do
    while ri <= #rows and rows[ri] <= unit.start_row do ri = ri + 1 end
    local j = ri
    while j <= #rows and rows[j] < unit.end_row do
      unit.split_rows[#unit.split_rows + 1] = rows[j]
      j = j + 1
    end
  end
  return units
end

--- Greedily pack units into chunks.
---
--- Invariants (asserted by the tests):
---   * every unit lands in exactly one chunk, in document order
---   * a boundary is only ever placed BETWEEN units
---   * chunk.tokens <= target, unless the chunk holds a single unit that alone
---     exceeds it, in which case chunk.oversized is true
local function pack_chunks(units, target)
  local chunks = {}
  local current, current_tokens

  local function flush()
    if current then chunks[#chunks + 1] = current end
    current, current_tokens = nil, 0
  end

  for _, unit in ipairs(units) do
    if not current then
      current, current_tokens = { units = { unit } }, unit.tokens
      current.tokens = current_tokens
    elseif current_tokens + unit.tokens <= target then
      current.units[#current.units + 1] = unit
      current_tokens = current_tokens + unit.tokens
      current.tokens = current_tokens
    elseif unit.tokens > target then
      -- Current chunk is full and this unit can never fit anywhere, so it gets
      -- a chunk of its own. flush() clears `current`, so this branch must not
      -- touch it afterwards; the post-loop pass flags it oversized.
      flush()
      chunks[#chunks + 1] = { units = { unit }, tokens = unit.tokens }
    else
      flush()
      current, current_tokens = { units = { unit } }, unit.tokens
      current.tokens = current_tokens
    end
  end
  flush()

  -- A chunk holding one oversized unit is flagged even when it was created by
  -- the `not current` branch.
  for _, chunk in ipairs(chunks) do
    if #chunk.units == 1 and chunk.units[1].tokens > target then
      chunk.oversized = true
    end
  end
  return chunks
end

--- Draw one chunk: background stripe, boundary marker, hazard annotation.
local function render_chunk(bufnr, chunk, index, cfg)
  local first = chunk.units[1]
  local last = chunk.units[#chunk.units]
  local tokens = math.floor(chunk.tokens + 0.5)

  if cfg.stripe then
    -- One extmark spanning the chunk with line_hl_group instead of one
    -- add_highlight per line: measured ~20x cheaper on an 8k-line buffer
    -- (0.11ms vs 2.41ms) and it keeps the namespace small.
    vim.api.nvim_buf_set_extmark(bufnr, ns, first.start_row, 0, {
      end_line = math.min(last.end_row + 1, vim.api.nvim_buf_line_count(bufnr)),
      line_hl_group = (index % 2 == 0) and 'ChunkEven' or 'ChunkOdd',
    })
  end

  if not cfg.virt_text then return end

  -- A hazard outranks a size warning: an unclosed tag is the defect to fix.
  local label, hl
  if first.hazard then
    if first.hazard.kind == 'mismatched' then
      label = string.format(' MISMATCH </%s> does not close <%s> ', first.hazard.name or '?', first.hazard.name or '?')
    else
      label = string.format(' UNCLOSED <%s> has no end tag -- chunk clips here ', first.hazard.name or '?')
    end
    hl = 'ChunkClip'
  elseif chunk.oversized then
    local splits = first.split_rows or {}
    if #splits > 0 then
      label = string.format(' OVERSIZED %d tokens -- split at %d heading(s) inside <%s> ',
        tokens, #splits, first.name or '?')
    else
      label = string.format(' OVERSIZED %d tokens -- <%s> has no heading to split on ',
        tokens, first.name or '?')
    end
    hl = 'ChunkOversized'
  else
    local closing_line = vim.api.nvim_buf_get_lines(bufnr, last.end_row, last.end_row + 1, false)[1]
    local clean_close = closing_line ~= nil and vim.trim(closing_line):match('^</') ~= nil
    label = string.format(' chunk %d · %d tokens %s ',
      index, tokens, clean_close and '✓ ends on close tag' or '· cut')
    hl = clean_close and 'ChunkBoundaryIdeal' or 'ChunkBoundaryGood'
  end

  vim.api.nvim_buf_set_extmark(bufnr, ns, last.end_row, 0, {
    virt_text = { { label, hl } },
    virt_text_pos = 'right_align',
  })
end

--- Analyze and draw a buffer.
--- @return table[] chunks  the chunk list (each: units, tokens, oversized)
--- @return table summary   counts for the status message
function M.analyze(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cfg = M.config
  M.define_highlights()
  M.clear(bufnr)

  local root = promptmd_root(bufnr)
  local units

  if root then
    -- One lines read per analyze, shared by unit weights and the heading
    -- scan (both need every line; fetching twice doubled the copy cost).
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    units = build_units(root, bufnr, lines)
  else
    -- No promptmd structure: one unit for the whole buffer, so token and
    -- oversized reporting still works for plain .md and .txt.
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local total = 0
    for _, line in ipairs(lines) do
      total = total + estimate_tokens(line, cfg.chars_per_token)
    end
    units = { { start_row = 0, end_row = math.max(line_count - 1, 0), tokens = total, kind = 'buffer' } }
  end

  local chunks = pack_chunks(units, cfg.target_tokens)

  local summary = { chunks = #chunks, oversized = 0, hazards = 0, tokens = 0 }
  for i, chunk in ipairs(chunks) do
    render_chunk(bufnr, chunk, i, cfg)
    summary.tokens = summary.tokens + chunk.tokens
    if chunk.oversized then summary.oversized = summary.oversized + 1 end
    if chunk.units[1].hazard then summary.hazards = summary.hazards + 1 end
  end
  return chunks, summary
end

function M.clear(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr or vim.api.nvim_get_current_buf(), ns, 0, -1)
end

--- Debounced re-analyze: coalesce bursts of edits into one pass.
---
--- One timer PER BUFFER. A single shared timer is a race: editing buffer B
--- within A's debounce window calls stop() on the timer whose pending callback
--- names A, so A's re-analyze is silently dropped and A keeps a stale overlay
--- until something else re-analyzes it. Verified: two promptmd buffers edited
--- back-to-back left the first with 0 marks. Per-buffer timers also give each
--- buffer its own idle window, which is the semantics the debounce is for.
---
--- Declared before enable/disable, which call cancel_refresh(): a `local`
--- is only visible to code textually below it.
local refresh_timers = {}
local function schedule_refresh(bufnr)
  local timer = refresh_timers[bufnr]
  if not timer then
    timer = vim.uv.new_timer()
    refresh_timers[bufnr] = timer
  end
  timer:stop()
  timer:start(M.config.refresh_on_edit, 0, vim.schedule_wrap(function()
    -- The timer handle is deliberately NOT closed here: closing a uv handle
    -- from inside its own callback is fragile, and keeping it costs one handle
    -- per buffer (released on BufUnload) while letting a burst of edits reuse
    -- it. The enabled + validity checks below are what make a late fire safe.
    if vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].chunked_enabled then
      M.analyze(bufnr)
    end
  end))
end

--- Drop a buffer's pending refresh and release its timer.
local function cancel_refresh(bufnr)
  local timer = refresh_timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    refresh_timers[bufnr] = nil
  end
end

--- Turn chunk visualization on for one buffer (idempotent).
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr].chunked_enabled = true
  return M.analyze(bufnr)
end

--- Turn it off and wipe the overlays.
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  vim.b[bufnr].chunked_enabled = false
  cancel_refresh(bufnr)
  M.clear(bufnr)
end

function M.setup(opts)
  M.config = vim.tbl_extend('force', M.defaults, opts or {})
  M.define_highlights()

  local group = vim.api.nvim_create_augroup('chunked', { clear = true })

  -- Re-chunk after a write: catches changes that TextChanged misses (external
  -- writes picked up via :checktime land as a fresh buffer load, but a plain
  -- :w of a manually adjusted prompt re-renders the boundary labels at once).
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    callback = function(ev)
      if vim.b[ev.buf].chunked_enabled then M.analyze(ev.buf) end
    end,
    desc = 'Re-chunk promptmd buffer after write',
  })

  -- Keep the token cache and any pending refresh from outliving their buffer.
  -- Dropping the timer here is what stops a queued re-analyze firing against
  -- a recycled buffer handle.
  vim.api.nvim_create_autocmd('BufUnload', {
    group = group,
    callback = function(ev)
      M._token_cache[ev.buf] = nil
      cancel_refresh(ev.buf)
    end,
    desc = 'Drop cached token estimate and pending refresh for an unloaded buffer',
  })

  -- Chunking is ambient, not opt-in: this editor's buffers are overwhelmingly
  -- model-driven prompts, and a visualization that must be remembered is a
  -- visualization that is not used. <Leader>ct stays as the per-buffer escape
  -- hatch (it flips b:chunked_enabled, which every trigger below checks).
  vim.api.nvim_create_autocmd({ 'FileType', 'Syntax' }, {
    group = group,
    callback = function(ev)
      if M.is_measured(vim.bo[ev.buf].filetype) and vim.b[ev.buf].chunked_enabled == nil then
        -- == nil, not falsy: an explicit `false` means the user turned Chunk
        -- off in this buffer and re-detection must not override that.
        M.enable(ev.buf)
      end
    end,
    desc = 'Auto-enable chunk visualization on prompt filetypes',
  })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = group,
    callback = function(ev)
      if vim.b[ev.buf].chunked_enabled then schedule_refresh(ev.buf) end
    end,
    desc = 'Re-chunk after edits (debounced)',
  })

  -- Buffers whose filetype was already set before setup() ran (the ones
  -- opened on the command line have theirs set during startup).
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr)
        and M.is_measured(vim.bo[bufnr].filetype)
        and vim.b[bufnr].chunked_enabled == nil then
      M.enable(bufnr)
    end
  end
end

return M
