-- Markup tag editing for the four markup filetypes: xml, html, markdown, promptmd.
--
-- Wired in per-buffer from after/ftplugin/{xml,html,markdown,promptmd}.lua via
-- `require('xml_surround').setup_buffer()`. Everything here is buffer-local --
-- no global mapping, no global mini.surround config -- so other filetypes see
-- no behaviour change at all.
--
-- Two mechanisms:
--
--   A. Typing the `>` that closes an OPENING tag explodes it into three lines
--      with a matching closing tag, cursor parked on the indented middle line,
--      still in insert mode.
--
--   B. Visual `sat` wraps the selection in an EMPTY `<>` / `</>` pair, splits it
--      over three lines, and drops you inside the `<>` so the tag name is typed
--      once; on InsertLeave the name is mirrored into the closing tag and a
--      markdown h1 copy of the opening tag (`yyp`, `sad` on the angle
--      brackets, `# ` in front) is inserted right below it:
--
--          <rules>
--          # rules
--              selection
--          </rules>
--
-- This config has no markup formatter and no markup LSP, so indentation is
-- computed here (current line's indent + one 'shiftwidth') rather than delegated.
--
-- Mechanism A deliberately refuses to fire on closing tags, self-closing tags,
-- `<!...>` / `<?...?>`, a `>` inside a quoted attribute value, and prose `>`.
-- The detector is a left-to-right state machine over the text left of the
-- cursor, backed by a best-effort treesitter veto for MULTI-LINE comments and
-- CDATA that a single-line scan cannot see.
--
-- Mechanism B overrides only the `output` half of mini.surround's builtin `t`
-- surrounding, so `sdt`/`sft`/`srt` keep matching real tag pairs. mini calls
-- `output()` with no arguments and provides no post-add hook or User autocmd
-- (verified in surround.lua: `H.get_surround_spec` does a bare `res()`, and
-- `H.create_autocommands` only registers ColorScheme), so the insertion points
-- are captured as extmarks BEFORE mini edits the buffer and the reformat runs
-- from `vim.schedule()`.

local M = {}

local ns = vim.api.nvim_create_namespace('xml_surround')

--- One indent step for the current buffer. `shiftwidth()` (the function, not the
--- option) already falls back to 'tabstop' when 'shiftwidth' is 0.
local function indent_unit()
  if vim.bo.expandtab then return string.rep(' ', vim.fn.shiftwidth()) end
  return '\t'
end

-- Mechanism A: auto-close on typing `>` ======================================

--- Classify the text that will sit to the LEFT of a just-typed `>`.
---@param before string Text left of the cursor.
---@return string state One of TEXT|INTAG|INATTR|CLOSING|SPECIAL.
---@return integer|nil tag_start 1-based index of the `<` that opened the tag.
local function scan_before(before)
  local state, tag_start, quote = 'TEXT', nil, nil
  for i = 1, #before do
    local c = before:sub(i, i)
    if state == 'TEXT' then
      if c == '<' then
        local nxt = before:sub(i + 1, i + 1)
        if nxt == '/' then
          state = 'CLOSING'
        elseif nxt == '!' or nxt == '?' then
          state = 'SPECIAL'
        elseif nxt:match('^[%a_]$') then
          state, tag_start = 'INTAG', i
        end
        -- Anything else -- space, digit, another `<`, end of line -- is prose
        -- like `a < b`, so stay in TEXT.
      end
    elseif state == 'INTAG' then
      if c == '"' or c == "'" then
        state, quote = 'INATTR', c
      elseif c == '>' then
        state = 'TEXT'
      end
    elseif state == 'INATTR' then
      -- Only the matching quote closes the value, which is what makes
      -- `<a title="a > b">` work.
      if c == quote then state, quote = 'INTAG', nil end
    elseif state == 'CLOSING' or state == 'SPECIAL' then
      if c == '>' then state = 'TEXT' end
    end
  end
  return state, tag_start
end

--- Best-effort treesitter veto for a cursor inside a MULTI-LINE comment or CDATA
--- section, which `scan_before` cannot see. Never errors, and never vetoes when
--- no parser is available -- the state machine's verdict stands in that case.
local function in_comment_or_cdata()
  local ok, inside = pcall(function()
    local parser = vim.treesitter.get_parser(0)
    if parser == nil then return false end
    parser:parse(true)
    local node = vim.treesitter.get_node({ bufnr = 0 })
    while node ~= nil do
      local kind = node:type():lower()
      if kind:find('comment', 1, true) or kind:find('cdata', 1, true) then return true end
      node = node:parent()
    end
    return false
  end)
  return ok and inside
end

--- Insert-mode `>`. Non-expr mapping, so this owns every buffer change --
--- including inserting the literal `>` on the non-expanding path. (An expr
--- mapping cannot be used: insert-mode expr mappings are textlock'd.)
local function type_gt()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local row0 = row - 1
  local line = vim.api.nvim_get_current_line()
  local before = line:sub(1, col)

  local function insert_plain()
    vim.api.nvim_buf_set_text(0, row0, col, row0, col, { '>' })
    vim.api.nvim_win_set_cursor(0, { row, col + 1 })
  end

  local state, tag_start = scan_before(before)
  -- `vim.b.xml_surround_pending` is Mechanism B's live-session guard: a `>`
  -- typed inside its `<>` name slot must not recurse into an expansion.
  if state ~= 'INTAG' or before:sub(-1) == '/' or vim.b.xml_surround_pending then
    return insert_plain()
  end

  local name = before:sub(tag_start):match('^<([%a_][%w_%%-%.:]*)')
  if name == nil or in_comment_or_cdata() then return insert_plain() end

  local indent = line:match('^%s*')
  local inner = indent .. indent_unit()
  vim.api.nvim_buf_set_lines(0, row0, row0 + 1, false, {
    before .. '>',
    inner .. line:sub(col + 1),
    indent .. '</' .. name .. '>',
  })
  vim.api.nvim_win_set_cursor(0, { row + 1, #inner })
end

-- Mechanism B: visual `sat` with the name typed once =========================

-- mini.surround's builtin `t` input patterns, copied verbatim so that replacing
-- only `output` leaves `sdt`/`sft`/`srt` matching real tag pairs. Source:
-- ~/.local/share/nvim/site/pack/deps/start/mini.nvim/lua/mini/surround.lua:1140
local TAG_INPUT = { '<(%w-)%f[^<%w][^<>]->.-</%1>', '^<.->().*()</[^/]->$' }

--- 0-based byte column mini inserts the right part at, given a raw 0-based
--- "second mark" column. Mirrors `H.get_marks_pos`'s multibyte rounding
--- (surround.lua:1926-1934): the mark is nudged to the LAST byte of its
--- character, then the insert happens one byte past that.
local function right_insert_col(buf, row0, col0)
  local line = vim.api.nvim_buf_get_lines(buf, row0, row0 + 1, false)[1] or ''
  if #line == 0 then return 0 end
  local i = math.min(#line, col0 + 1)
  local ok, off = pcall(vim.str_utf_end, line, i)
  return i + (ok and off or 0)
end

local function point_extmark(buf, row0, col0)
  -- `right_gravity = false` keeps the mark pinned to the LEFT of whatever mini
  -- inserts at this exact position, so afterwards it points at the first byte
  -- of the inserted marker.
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, row0, col0, { right_gravity = false })
  if ok then return id end
  return nil
end

--- Anchor every region mini could be about to surround. `output()` receives no
--- arguments, so the region has to be read from marks: `'<`/`'>` for a visual
--- add, `'[`/`']` for an operator add (`saiwt`). Both are anchored and the right
--- one is identified afterwards by checking which anchors actually landed on the
--- inserted markers -- which is also why an unrelated `<>` elsewhere in the
--- buffer cannot be mistaken for ours.
local function anchor_candidates(buf)
  local candidates = {}
  for _, marks in ipairs({ { '<', '>' }, { '[', ']' } }) do
    local from = vim.api.nvim_buf_get_mark(buf, marks[1])
    local to = vim.api.nvim_buf_get_mark(buf, marks[2])
    if from[1] >= 1 and to[1] >= 1 then
      local left = point_extmark(buf, from[1] - 1, from[2])
      local right = point_extmark(buf, to[1] - 1, right_insert_col(buf, to[1] - 1, to[2]))
      if left ~= nil and right ~= nil then
        table.insert(candidates, { left = left, right = right })
      end
    end
  end
  return candidates
end

local function extmark_pos(buf, id)
  local pos = vim.api.nvim_buf_get_extmark_by_id(buf, ns, id, {})
  if pos[1] == nil then return nil end
  return pos[1], pos[2]
end

local function text_at(buf, row0, col0, len)
  local ok, chunks = pcall(vim.api.nvim_buf_get_text, buf, row0, col0, row0, col0 + len, {})
  if not ok then return nil end
  return chunks[1]
end

--- Resolve a candidate to the region mini actually surrounded, or nil.
---
--- The anchors sit exactly where mini inserts for a charwise selection. For a
--- LINEWISE one (`V` + `sat`) mini skips the line's leading whitespace, so the
--- left marker lands to the right of the `'<` anchor: accept it if only
--- whitespace separates the two.
local function locate(buf, candidate)
  local lrow, lcol = extmark_pos(buf, candidate.left)
  local rrow, rcol = extmark_pos(buf, candidate.right)
  if lrow == nil or rrow == nil then return nil end
  if text_at(buf, lrow, lcol, 2) ~= '<>' then
    local line = vim.api.nvim_buf_get_lines(buf, lrow, lrow + 1, false)[1] or ''
    local ws_end = select(2, line:find('^%s*', lcol + 1))
    if line:sub(ws_end + 1, ws_end + 2) ~= '<>' then return nil end
    lcol = ws_end
  end
  if text_at(buf, rrow, rcol, 3) ~= '</>' then return nil end
  return { lrow = lrow, lcol = lcol, rrow = rrow, rcol = rcol }
end

--- Mirror the tag NAME typed into the opening slot across to the closing slot,
--- insert the h1 copy of the opening tag below it, then tear the session down.
--- Only the first whitespace-delimited token is mirrored, so `<div class="x">`
--- closes as `</div>` -- consistent with Mechanism A, which also closes with
--- the bare name. The h1 line keeps EVERYTHING typed (`# div class="x"`),
--- exactly what `yyp` + `sad` on the brackets would leave.
local function arm_mirror(buf, open_id, close_id)
  vim.api.nvim_create_autocmd('InsertLeave', {
    buffer = buf,
    once = true,
    desc = 'xml_surround: mirror typed tag name into the closing tag',
    callback = function()
      -- A stale or invalidated extmark must never throw at the user.
      pcall(function()
        local open = vim.api.nvim_buf_get_extmark_by_id(buf, ns, open_id, { details = true })
        if open[1] == nil then return end
        local typed = table.concat(
          vim.api.nvim_buf_get_text(buf, open[1], open[2], open[3].end_row, open[3].end_col, {}),
          ''
        )
        local name = typed:match('^%S*')
        local close = vim.api.nvim_buf_get_extmark_by_id(buf, ns, close_id, {})
        -- Nothing typed (plain `<Esc>`) leaves `<>` / `</>` alone, no error.
        if name == '' or close[1] == nil then return end
        vim.api.nvim_buf_set_text(buf, close[1], close[2], close[1], close[2], { name })
        -- Header copy AFTER the mirror: inserting a line above the closing tag
        -- would shift the row just read from `close`.
        local open_line = vim.api.nvim_buf_get_lines(buf, open[1], open[1] + 1, false)[1] or ''
        local indent = open_line:match('^%s*')
        vim.api.nvim_buf_set_lines(buf, open[1] + 1, open[1] + 1, false, { indent .. '# ' .. typed })
      end)
      pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
      pcall(function() vim.b[buf].xml_surround_pending = nil end)
    end,
  })
end

--- Split `<>selection</>` over three lines and start the naming session.
local function reformat(buf, at)
  local start_line = vim.api.nvim_buf_get_lines(buf, at.lrow, at.lrow + 1, false)[1] or ''
  local end_line = vim.api.nvim_buf_get_lines(buf, at.rrow, at.rrow + 1, false)[1] or ''
  local indent = start_line:match('^%s*')
  -- `prefix` already carries the line's indent; re-indenting is what normalises
  -- a selection that started inside the leading whitespace.
  local prefix = start_line:sub(1, at.lcol):sub(#indent + 1)
  local suffix = end_line:sub(at.rcol + 4)
  local body = vim.api.nvim_buf_get_text(buf, at.lrow, at.lcol + 2, at.rrow, at.rcol, {})
  local inner = indent .. indent_unit()

  -- The anchors have been read; drop them before the edit so only the two name
  -- slots live in the namespace.
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local lines = { indent .. prefix .. '<>' }
  for _, text in ipairs(body) do
    table.insert(lines, inner .. text:gsub('^%s*', ''))
  end
  table.insert(lines, indent .. '</>' .. suffix)
  vim.api.nvim_buf_set_lines(buf, at.lrow, at.rrow + 1, false, lines)

  local open_col = #indent + #prefix + 1
  -- Zero-width range, `right_gravity = false` + `end_right_gravity = true`, so
  -- the name typed at this point grows INSIDE the tracked range.
  local open_id = vim.api.nvim_buf_set_extmark(buf, ns, at.lrow, open_col, {
    end_row = at.lrow,
    end_col = open_col,
    right_gravity = false,
    end_right_gravity = true,
  })
  local close_id = vim.api.nvim_buf_set_extmark(buf, ns, at.lrow + #body + 1, #indent + 2, {
    right_gravity = false,
  })

  vim.b[buf].xml_surround_pending = true
  arm_mirror(buf, open_id, close_id)
  vim.api.nvim_win_set_cursor(0, { at.lrow + 1, open_col })
  vim.cmd('startinsert')
end

--- `output` half of the `t` surrounding: wrap with empty markers now, reformat
--- and start the naming session once mini has finished its own edits.
local function tag_output()
  local buf = vim.api.nvim_get_current_buf()
  local candidates = anchor_candidates(buf)

  vim.schedule(function()
    local done = false
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
      for _, candidate in ipairs(candidates) do
        local at = locate(buf, candidate)
        if at and pcall(reformat, buf, at) then
          done = true
          break
        end
      end
    end
    -- Nothing recognisable: leave mini's plain `<>` / `</>` in place and clean up.
    if not done then pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1) end
  end)

  return { left = '<>', right = '</>' }
end

-- Wiring =====================================================================

--- Enable both mechanisms for the current buffer.
function M.setup_buffer()
  vim.keymap.set('i', '>', type_gt, { buffer = true, desc = 'Auto-close opening tag' })

  -- `vim.b` hands back a COPY, so mutating a nested field in place is silently
  -- lost. Read the whole table, mutate, reassign -- which also preserves any
  -- surroundings an earlier ftplugin already registered (markdown's `L`).
  local cfg = vim.b.minisurround_config or {}
  cfg.custom_surroundings = cfg.custom_surroundings or {}
  cfg.custom_surroundings.t = { input = TAG_INPUT, output = tag_output }
  vim.b.minisurround_config = cfg
end

return M
