-- Tests for blended xml-tag + markdown highlighting under indentation.
-- Run with: nvim --headless -c "luafile tests/test_indented_markup.lua" -c "qa!"
--
-- The claim under test: in .md, .xmd and .xml buffers, markdown between tag
-- lines is highlighted as markdown no matter how far it is indented, and tag
-- lines are highlighted as tags no matter how far they are indented. These
-- run against the real parsers and the real queries/ directory, through real
-- files on disk so filetype detection is part of what is tested.

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

local tmpdir = vim.fn.tempname()
vim.fn.mkdir(tmpdir, 'p')

--- Write `lines` to a file with extension `ext`, edit it, parse every
--- injection, and return the buffer number.
local function open(ext, lines)
  local path = string.format('%s/case_%d.%s', tmpdir, passed + failed, ext)
  vim.fn.writefile(lines, path)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()
  -- Started with no file argument, this config defers its FileType
  -- tree-sitter autocmd (`Config.now_if_args`), so nothing has started a
  -- highlighter for xml yet; promptmd buffers start theirs in the ftplugin.
  if not vim.treesitter.highlighter.active[buf] then vim.treesitter.start(buf) end
  vim.treesitter.get_parser(buf):parse(true)
  return buf
end

--- Set of "capture.lang" strings at the first occurrence of `needle` in the
--- buffer (at its first character).
local function captures_at(buf, needle)
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local col = line:find(needle, 1, true)
    if col then
      local set = {}
      for _, c in ipairs(vim.treesitter.get_captures_at_pos(buf, row - 1, col - 1)) do
        set[c.capture .. '.' .. c.lang] = true
      end
      return set
    end
  end
  error('needle not found in buffer: ' .. needle, 2)
end

local function has(buf, needle, capture)
  local set = captures_at(buf, needle)
  if not set[capture] then
    error(string.format('%q: expected capture %s, got {%s}', needle, capture,
      table.concat(vim.tbl_keys(set), ', ')), 2)
  end
end

local function lacks(buf, needle, capture)
  local set = captures_at(buf, needle)
  if set[capture] then error(string.format('%q: unexpected capture %s', needle, capture), 2) end
end

--- Prefix every line with `indent`, leaving blank lines blank.
local function indented(indent, lines)
  local out = {}
  for i, line in ipairs(lines) do
    out[i] = line == '' and '' or indent .. line
  end
  return out
end

local BODY = {
  '# Heading',
  'plain **strong** and `code` text',
  '',
  '```lua',
  'local x = 1',
  'if x then',
  '    print(x)',
  'end',
  '```',
  '',
  '1. **first** item',
  '2. second item',
  '',
  'closing _emphasis_ paragraph',
}

--- One section: `tag_indent` before the tag lines, `body_indent` before BODY.
local function section(tag_indent, body_indent)
  local lines = { tag_indent .. '<blocker kind="x">' }
  vim.list_extend(lines, indented(body_indent, BODY))
  lines[#lines + 1] = tag_indent .. '</blocker>'
  return lines
end

local function assert_body_highlighted(buf)
  has(buf, '# Heading', 'markup.heading.1.markdown')
  has(buf, '**strong**', 'markup.strong.markdown_inline')
  has(buf, '`code`', 'markup.raw.markdown_inline')
  has(buf, '```lua', 'markup.raw.block.markdown')
  has(buf, 'local x', 'keyword.lua')
  has(buf, 'print(x)', 'function.builtin.lua')
  has(buf, '1. **first**', 'markup.list.markdown')
  has(buf, '**first**', 'markup.strong.markdown_inline')
  has(buf, '_emphasis_', 'markup.italic.markdown_inline')
  -- Prose must never degrade into an (indented) code block.
  lacks(buf, 'plain', 'markup.raw.block.markdown')
  lacks(buf, 'closing', 'markup.raw.block.markdown')
end

local TAG = { md = 'tag.promptmd', xmd = 'tag.promptmd', xml = 'tag.xml' }
local INDENTS = { '', ' ', '  ', '    ', '        ', '            ', '\t', '\t\t' }

-- ------------------------------------------------- every extension x indent --

for _, ext in ipairs({ 'md', 'xmd', 'xml' }) do
  for _, indent in ipairs(INDENTS) do
    local label = string.format('%q', indent)
    check(ext .. ': body indented by ' .. label .. ' under flush tags', function()
      local buf = open(ext, section('', indent))
      assert_body_highlighted(buf)
      has(buf, 'blocker', TAG[ext])
    end)
  end

  check(ext .. ': nested sections, each level indented deeper', function()
    local lines = { '<outer>' }
    vim.list_extend(lines, section('    ', '        '))
    lines[#lines + 1] = '</outer>'
    local buf = open(ext, lines)
    assert_body_highlighted(buf)
    has(buf, 'outer', TAG[ext])
    has(buf, 'blocker', TAG[ext])
  end)

  check(ext .. ': ragged indentation (heading at 1, body at 4)', function()
    local buf = open(ext, {
      '<blocker>',
      ' # BLOCKER',
      '    `just install` **refuses** from a branch',
      '',
      '    ```',
      '    FAIL a. tree dirty',
      '    ```',
      '',
      '    Note (a) is **also** uncommitted',
      '</blocker>',
    })
    has(buf, '# BLOCKER', 'markup.heading.1.markdown')
    has(buf, '`just install`', 'markup.raw.markdown_inline')
    has(buf, '**refuses**', 'markup.strong.markdown_inline')
    has(buf, 'FAIL a.', 'markup.raw.block.markdown')
    has(buf, '**also**', 'markup.strong.markdown_inline')
    lacks(buf, 'Note', 'markup.raw.block.markdown')
  end)

  check(ext .. ': heading flush, body indented by 8', function()
    local buf = open(ext, {
      '<blocker>',
      '# Flush',
      '        deep **strong** paragraph',
      '</blocker>',
    })
    has(buf, '# Flush', 'markup.heading.1.markdown')
    has(buf, '**strong**', 'markup.strong.markdown_inline')
    lacks(buf, 'deep', 'markup.raw.block.markdown')
  end)

  check(ext .. ': nested list and over-indented paragraph after a list', function()
    local buf = open(ext, {
      '<blocker>',
      '    - item one',
      '        - nested `code`',
      '          continuation **strong**',
      '    - item two',
      '',
      '                far **right** paragraph',
      '</blocker>',
    })
    has(buf, '- item one', 'markup.list.markdown')
    has(buf, '- nested', 'markup.list.markdown')
    has(buf, '`code`', 'markup.raw.markdown_inline')
    has(buf, '**strong**', 'markup.strong.markdown_inline')
    has(buf, '**right**', 'markup.strong.markdown_inline')
    lacks(buf, 'far', 'markup.raw.block.markdown')
  end)
end

-- ------------------------------------------------------------- .md / .xmd only --

for _, ext in ipairs({ 'md', 'xmd' }) do
  check(ext .. ': tag-looking line inside an indented fence stays code', function()
    local buf = open(ext, {
      '<rules>',
      '    ```',
      '    <fake>',
      '    ```',
      '    after **strong**',
      '</rules>',
    })
    has(buf, '<fake>', 'markup.raw.block.markdown')
    lacks(buf, 'fake', 'tag.promptmd')
    has(buf, '**strong**', 'markup.strong.markdown_inline')
  end)
end

-- --------------------------------------------------------------------- report --

vim.fn.delete(tmpdir, 'rf')
print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then vim.cmd('cq 1') end
