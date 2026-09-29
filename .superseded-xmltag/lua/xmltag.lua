-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ xmltag: insert-mode tag auto-close + visual `sat` tag wrap                │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- Two features, buffer-local to markdown / markdown.promptmd / xml / html:
--
-- 1. Insert-mode `>` completes `<name attrs>` into a matching pair (inline
--    `<name>|</name>` or, on an otherwise-empty line, a 3-line block with the
--    cursor on the blank middle line). Plain `>` (comparisons, `->`, closing
--    tags, self-closing tags, comments) is untouched.
-- 2. Visual `sat` wraps the selection in a tag pair vim-surround style, then
--    mirrors the typed name onto the closing tag live as you type it.
--
-- Both features avoid Vim's native indentexpr/autoindent entirely and compute
-- indentation themselves (see `shiftwidth_str`/INDENT POLICY below) so the
-- result is deterministic across filetypes regardless of which indent plugins
-- happen to be loaded -- required because xml/html and markdown disagree on
-- whether content should be indented at all (see `M.config.indent`).
--
-- Buffer mutations use `nvim_buf_set_text`/`nvim_buf_set_lines` (not fed
-- keystrokes) for precision, each preceded by `pcall(vim.cmd, 'undojoin')` so
-- a whole auto-close or wrap-and-type session collapses into one undo step
-- like a native pair-completion would.

local M = {}

-- INDENT POLICY (config table, per `setup({ indent = {...} })`):
--   xml/html      -> content indented one 'shiftwidth' relative to the tags.
--   markdown(.*)  -> content stays flush with the opening tag's indent.
--                    4+ leading spaces reads as an indented code block in
--                    markdown, so indenting content there would corrupt it.
--                    v1 limitation: nested TAG-only lines are not indented
--                    either (spec allows falling back to "everything flush"
--                    if the nested-tag-only case is too complex for v1).
M.config = {
  indent = {
    xml = true,
    html = true,
    markdown = false,
    ['markdown.promptmd'] = false,
  },
}

local ENABLED_FILETYPES = { 'markdown', 'markdown.promptmd', 'xml', 'html' }

-- Tag name: `[A-Za-z_][A-Za-z0-9_.:-]*` translated to a Lua pattern (`%w` is
-- alnum only, no underscore, so `_` is added explicitly to both classes).
local TAG_NAME = '[%a_][%w_.:%-]*'

-- Node types that suppress auto-close/wrap detection, per filetype. xml/html
-- come from the compiled parsers on this machine (verified via `strings` on
-- xml.so/html.so: xml uses `Comment`/`CData`, html uses lowercase `comment`).
-- markdown(.promptmd) come from tree-sitter-markdown(-inline); promptmd's own
-- grammar has no fence nodes at all -- its `content` blocks are injected as a
-- combined "markdown" parse (queries/promptmd/injections.scm), and
-- `vim.treesitter.get_node` descends into injections by default, so the same
-- markdown node types apply there too.
local EXCLUDED_NODE_TYPES = {
  markdown = { fenced_code_block = true, code_span = true },
  ['markdown.promptmd'] = { fenced_code_block = true, code_span = true },
  xml = { Comment = true, CData = true },
  html = { comment = true },
}

local function indent_enabled(ft)
  local v = M.config.indent[ft]
  return v == true
end

-- One 'shiftwidth' as a literal string, respecting 'expandtab'. Vim's own
-- `>>` builds this by re-tabbing the whole line; we only ever need a fresh
-- unit to prepend, so build it directly from 'tabstop' instead.
local function shiftwidth_str(bufnr)
  local sw = vim.fn.shiftwidth()
  if vim.bo[bufnr].expandtab then return string.rep(' ', sw) end
  local ts = vim.bo[bufnr].tabstop
  if ts <= 0 then ts = 8 end
  return string.rep('\t', math.floor(sw / ts)) .. string.rep(' ', sw % ts)
end

-- True if (row0, col0) sits inside a node type excluded for `ft` (fenced
-- code / code span for markdown, comment/CDATA for xml/html). Fails open
-- (returns false) if there's no parser -- exclusion is a nicety, not safety.
local function in_excluded_region(bufnr, ft, row0, col0)
  local excluded = EXCLUDED_NODE_TYPES[ft]
  if not excluded then return false end
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row0, col0 } })
  if not ok or not node then return false end
  while node do
    if excluded[node:type()] then return true end
    node = node:parent()
  end
  return false
end

-- ============================================================================
-- Feature 1: insert-mode `>` auto-close
-- ============================================================================

-- Scans `line` up to (but not including) the '>' about to be typed at `col`
-- (0-indexed) and decides whether it completes an auto-closeable opening tag.
-- Returns nil for: no unmatched '<', closing tag (`</x`), comment/doctype/PI
-- (`<!`, `<?`), self-closing (`.../ `), or no valid name.
local function analyze_gt(bufnr, ft, row, col, line)
  if in_excluded_region(bufnr, ft, row - 1, col) then return nil end

  local before = line:sub(1, col)
  -- Nearest unmatched '<' scanning backward: a '>' hit first means whatever
  -- tag was open here already closed, so there is nothing to complete.
  local lt
  for i = #before, 1, -1 do
    local c = before:sub(i, i)
    if c == '>' then break end
    if c == '<' then lt = i; break end
  end
  if not lt then return nil end

  local body = before:sub(lt + 1)
  if body:match('^/') then return nil end -- </name
  if body:match('^[!?]') then return nil end -- <!--, <!DOCTYPE, <?xml
  if body:match('/%s*$') then return nil end -- <name attrs / (self-closing)

  local name = body:match('^(' .. TAG_NAME .. ')')
  if not name then return nil end

  local before_lt = before:sub(1, lt - 1)
  local after_cursor = line:sub(col + 1)
  local is_block = before_lt:match('^%s*$') ~= nil and after_cursor == ''

  return { name = name, is_block = is_block, indent = before_lt }
end

function M._handle_gt()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()

  local ctx = analyze_gt(bufnr, ft, row, col, line)

  pcall(vim.cmd, 'undojoin')

  if not ctx then
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { '>' })
    vim.api.nvim_win_set_cursor(0, { row, col + 1 })
    return
  end

  local closing = '</' .. ctx.name .. '>'

  if ctx.is_block then
    local middle = indent_enabled(ft) and (ctx.indent .. shiftwidth_str(bufnr)) or ctx.indent
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { '>', middle, ctx.indent .. closing })
    vim.api.nvim_win_set_cursor(0, { row + 1, #middle })
  else
    vim.api.nvim_buf_set_text(bufnr, row - 1, col, row - 1, col, { '>' .. closing })
    vim.api.nvim_win_set_cursor(0, { row, col + 1 })
  end
end

-- ============================================================================
-- Feature 2: visual `sat` tag wrap, with live name mirroring
-- ============================================================================

local mirror_ns = vim.api.nvim_create_namespace('xmltag_mirror')

-- Minimum leading-whitespace prefix across non-blank lines; blank lines don't
-- count (a blank line's "indent" says nothing about the block's true level).
local function min_indent(lines)
  local min
  for _, l in ipairs(lines) do
    if l:match('%S') then
      local ind = l:match('^%s*')
      if not min or #ind < #min then min = ind end
    end
  end
  return min or ''
end

-- Adds `extra` between each line's shared `base` prefix and its own content,
-- preserving any indentation nested lines already have beyond `base`. Used
-- to shift a whole selection by one level while keeping relative structure.
local function reindent(lines, base, extra)
  if extra == '' then return lines end
  local out = {}
  for i, l in ipairs(lines) do
    if l:sub(1, #base) == base then
      out[i] = base .. extra .. l:sub(#base + 1)
    else
      out[i] = extra .. l
    end
  end
  return out
end

-- Live-mirrors the tag name from the opening tag to the closing tag while
-- insert mode stays open, then tears itself down on InsertLeave (restoring
-- the original text via `restore_fn` if the name was left empty).
--
-- Three extmarks track the moving pieces:
--   open_start - fixed right after the opening '<' (right_gravity=false: text
--                typed there pushes everything else right, this mark stays put)
--   open_gt    - sits on the opening tag's '>' (right_gravity=true, the
--                default: text typed before it pushes it forward with the '>')
-- `typed = line:sub(open_start+1, open_gt)` is always exactly the live name
-- +attrs text between those two marks.
--   close_slot - the closing tag's name region (`</|...|>`). We own every
--                write to it, so instead of relying on gravity to grow/shrink
--                it we just re-set it (same id) to the exact new range after
--                every replacement -- simpler than reasoning about gravity
--                for a region we fully control.
local function start_mirror(bufnr, open_pos, gt_pos, close_pos, restore_fn)
  local open_id = vim.api.nvim_buf_set_extmark(bufnr, mirror_ns, open_pos[1], open_pos[2], { right_gravity = false })
  local gt_id = vim.api.nvim_buf_set_extmark(bufnr, mirror_ns, gt_pos[1], gt_pos[2], { right_gravity = true })
  local close_id = vim.api.nvim_buf_set_extmark(bufnr, mirror_ns, close_pos[1], close_pos[2], {
    end_row = close_pos[1],
    end_col = close_pos[2],
  })

  local function current_name()
    local ok1, op = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, mirror_ns, open_id, {})
    local ok2, gp = pcall(vim.api.nvim_buf_get_extmark_by_id, bufnr, mirror_ns, gt_id, {})
    if not ok1 or not ok2 or #op == 0 or #gp == 0 or op[1] ~= gp[1] then return nil end
    local line = vim.api.nvim_buf_get_lines(bufnr, op[1], op[1] + 1, false)[1] or ''
    return line:sub(op[2] + 1, gp[2]):match('^%S*') or ''
  end

  local function sync_closing_name()
    local name = current_name()
    if not name then return end
    local cp = vim.api.nvim_buf_get_extmark_by_id(bufnr, mirror_ns, close_id, { details = true })
    if #cp == 0 then return end
    local crow, ccol, cend_row, cend_col = cp[1], cp[2], cp[3].end_row, cp[3].end_col
    pcall(vim.cmd, 'undojoin')
    vim.api.nvim_buf_set_text(bufnr, crow, ccol, cend_row, cend_col, { name })
    vim.api.nvim_buf_set_extmark(bufnr, mirror_ns, crow, ccol, { id = close_id, end_row = crow, end_col = ccol + #name })
  end

  local group = vim.api.nvim_create_augroup('xmltag_mirror_' .. open_id, { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChangedP' }, {
    group = group,
    buffer = bufnr,
    callback = sync_closing_name,
  })
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      sync_closing_name() -- catch the char that triggered InsertLeave itself
      local name = current_name()
      vim.api.nvim_del_augroup_by_id(group)
      pcall(vim.api.nvim_buf_del_extmark, bufnr, mirror_ns, open_id)
      pcall(vim.api.nvim_buf_del_extmark, bufnr, mirror_ns, gt_id)
      pcall(vim.api.nvim_buf_del_extmark, bufnr, mirror_ns, close_id)
      if name == nil or name == '' then
        pcall(vim.cmd, 'undojoin')
        restore_fn()
      end
    end,
  })
end

-- Charwise, single line. Inserting the closing `</>` before the opening `<>`
-- keeps `start_col0` valid for the second edit (edits never touch text
-- before the position they target), so the two calls compose in either
-- order as long as the later-in-the-line one runs first -- do it that way to
-- avoid recomputing offsets after each edit.
local function wrap_inline(bufnr, lnum, s_col, e_col)
  local row0, start_col0, end_col0 = lnum - 1, s_col - 1, e_col
  local orig_line = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1] or ''

  vim.api.nvim_buf_set_text(bufnr, row0, end_col0, row0, end_col0, { '</>' })
  vim.api.nvim_buf_set_text(bufnr, row0, start_col0, row0, start_col0, { '<>' })

  local cursor_col0 = start_col0 + 1 -- right after '<', before '>'
  vim.api.nvim_win_set_cursor(0, { lnum, cursor_col0 })
  vim.cmd('startinsert')

  -- Post-edit layout (start-insert shifts everything from start_col0 on by
  -- +2, including the already-inserted closing tag): '<'=start_col0,
  -- '>'=start_col0+1, wrapped text=[start_col0+2, end_col0+2),
  -- '<'=end_col0+2, '/'=end_col0+3, '>'=end_col0+4 -- so the name slot
  -- between '/' and '>' sits at end_col0+4.
  start_mirror(bufnr, { row0, cursor_col0 }, { row0, cursor_col0 }, { row0, end_col0 + 4 }, function()
    vim.api.nvim_buf_set_lines(bufnr, row0, row0 + 1, false, { orig_line })
  end)
end

-- Linewise / multi-line-charwise / blockwise (blockwise treated as linewise
-- per spec). Line counts never change again after this point during the
-- mirror session (only intra-line text is edited), so the opening/closing
-- tag row numbers captured here stay valid for the InsertLeave restore.
local function wrap_block(bufnr, ft, start_line, end_line)
  local start_row0, end_row0 = start_line - 1, end_line - 1
  local orig_lines = vim.api.nvim_buf_get_lines(bufnr, start_row0, end_row0 + 1, false)
  local base = min_indent(orig_lines)

  local content = indent_enabled(ft) and reindent(orig_lines, base, shiftwidth_str(bufnr)) or orig_lines

  local combined = { base .. '<>' }
  vim.list_extend(combined, content)
  table.insert(combined, base .. '</>')
  vim.api.nvim_buf_set_lines(bufnr, start_row0, end_row0 + 1, false, combined)

  local open_row0 = start_row0
  local close_row0 = end_row0 + 2 -- +1 opening tag line, +1 closing tag line
  local cursor_col0 = #base + 1 -- right after '<', before '>'
  vim.api.nvim_win_set_cursor(0, { open_row0 + 1, cursor_col0 })
  vim.cmd('startinsert')

  start_mirror(
    bufnr,
    { open_row0, cursor_col0 },
    { open_row0, cursor_col0 },
    { close_row0, #base + 2 }, -- '</' is 2 chars past `base`
    function()
      vim.api.nvim_buf_set_lines(bufnr, open_row0, close_row0 + 1, false, orig_lines)
    end
  )
end

function M._wrap_visual()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local mode = vim.fn.visualmode()
  local s_line, s_col = unpack(vim.fn.getpos("'<"), 2, 3)
  local e_line, e_col = unpack(vim.fn.getpos("'>"), 2, 3)

  if mode == 'v' and s_line == e_line then
    wrap_inline(bufnr, s_line, s_col, e_col)
  else
    wrap_block(bufnr, ft, math.min(s_line, e_line), math.max(s_line, e_line))
  end
end

-- ============================================================================
-- Wiring
-- ============================================================================

function M._attach(bufnr)
  if vim.bo[bufnr].buftype ~= '' then return end -- prompt/nofile buffers opt out
  vim.keymap.set('i', '>', M._handle_gt, { buffer = bufnr, desc = 'xmltag: auto-close tag' })
  -- String rhs (not a Lua function) to match mini.surround's own `sa` mapping
  -- idiom (`:<C-u>lua MiniSurround.add(...)<CR>`): guarantees we're back in
  -- Normal mode with '</'> set before the handler runs. `desc` is what
  -- mini.clue actually reads for its clue window (see plugin/30_mini.lua).
  vim.keymap.set('x', 'sat', [[:<C-u>lua require('xmltag')._wrap_visual()<CR>]], {
    buffer = bufnr,
    silent = true,
    desc = 'Surround with XML tag',
  })
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
  local group = vim.api.nvim_create_augroup('xmltag_attach', { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    -- Compound filetypes ('markdown.promptmd') are not split for autocmd
    -- pattern matching, so it's listed explicitly alongside 'markdown'.
    pattern = ENABLED_FILETYPES,
    desc = 'xmltag: attach buffer-local tag auto-close + sat wrap',
    callback = function(args) M._attach(args.buf) end,
  })
end

return M
