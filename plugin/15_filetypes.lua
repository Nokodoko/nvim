-- bisect guard: nvim --cmd "let g:skip_plugins = ['15_filetypes']" skips this file
if vim.g.skip_plugins and vim.tbl_contains(vim.g.skip_plugins, '15_filetypes') then return end
-- Filetype detection for template files (Jinja2, Ansible, Helm)

-- promptmd: markdown that uses XML-style tag LINES ("<rules>", "</rules>")
-- as section boundaries, with plain markdown content between them and no
-- fencing either way. A tag line = optional whitespace, then
-- "<name attrs*>" / "</name>" / "<name attrs*/>", then optional whitespace,
-- alone on its line -- a mid-line mention like "use only <context> here" is
-- NOT a tag. See ~/Programs/tree-sitter-promptmd for the grammar; this
-- detector only needs to answer "does this .md file look like promptmd",
-- the tree-sitter grammar owns the real parse.

-- Validates that `attrs` consists only of zero or more whitespace-separated
-- `name="value"` / `name='value'` attributes (optional surrounding
-- whitespace), nothing else. Needed because Lua patterns have no way to
-- exclude '>' from a lazy `.-` match: naively capturing "everything between
-- the tag name and the LAST '>' on the line" also matches lines with an
-- open+close pair on one line, e.g. "<source>foo</source>" -- without this
-- check that reads as an open tag named "source" with garbage attributes.
local function promptmd_valid_attrs(attrs)
  local i, n = 1, #attrs
  while i <= n do
    local _, ws_e = attrs:find("^%s*", i)
    i = ws_e + 1
    if i > n then break end
    local name_s, name_e = attrs:find("^[%a_][%w_.%-]*", i)
    if not name_s then return false end
    i = name_e + 1
    if attrs:sub(i, i) ~= "=" then return false end
    i = i + 1
    local quote = attrs:sub(i, i)
    if quote ~= '"' and quote ~= "'" then return false end
    local close = attrs:find(quote, i + 1, true)
    if not close then return false end
    i = close + 1
  end
  return true
end

-- Classifies one already-trimmed line as an open/close/self-closing tag
-- line, or nil if it isn't one.
local function promptmd_tag_line(body)
  if body == "" then return nil end
  local close_name = body:match("^</([%a_][%w_.%-]*)>$")
  if close_name then return "close", close_name end
  local name, rest = body:match("^<([%a_][%w_.%-]*)(.-)>$")
  if not name then return nil end
  local self_closing = rest:match("/%s*$") ~= nil
  local attrs = self_closing and rest:sub(1, -2) or rest
  if not promptmd_valid_attrs(attrs) then return nil end
  return self_closing and "selfclose" or "open", name
end

-- Classifies one already-trimmed line as a fence delimiter (3+ of the same
-- backtick/tilde), returning the char and run length, or nil. (No `%1`
-- back-reference here: verified empirically that a single-char capture
-- class like `([`~])(%1*)` does not repeat-match in Lua patterns the way a
-- literal-string back-reference would.)
local function promptmd_fence_marker(body)
  local run = body:match("^(```+)") or body:match("^(~~~+)")
  if not run then return nil end
  return run:sub(1, 1), #run
end

-- Scans up to `limit` lines, skipping fenced regions (tag-look-alikes
-- inside a fence are not tags, matching the grammar), looking for an
-- opening tag line with a later matching closing tag line.
local function has_promptmd_structure(bufnr, limit)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, limit, false)
  local in_fence, fence_char, fence_len = false, nil, 0
  local open_names = {}
  for _, line in ipairs(lines) do
    local body = line:match("^%s*(.-)%s*$")
    local fch, flen = promptmd_fence_marker(body)
    if fch then
      if not in_fence then
        in_fence, fence_char, fence_len = true, fch, flen
      elseif fch == fence_char and flen >= fence_len then
        in_fence = false
      end
    elseif not in_fence then
      local kind, name = promptmd_tag_line(body)
      if kind == "open" then
        open_names[name] = true
      elseif kind == "close" and open_names[name] then
        return true
      end
    end
  end
  return false
end

local PROMPTMD_SCAN_LIMIT = 500

local function detect_markdown_variant(_, bufnr)
  if not bufnr or bufnr < 0 or not vim.api.nvim_buf_is_valid(bufnr) then
    return "markdown"
  end
  if has_promptmd_structure(bufnr, PROMPTMD_SCAN_LIMIT) then
    return "markdown.promptmd"
  end
  return "markdown"
end

-- Makes `vim.treesitter.language.get_lang("markdown.promptmd")` resolve to
-- the promptmd parser (belt-and-suspenders for anything that resolves a
-- buffer's parser from its filetype string without an explicit lang
-- argument, e.g. `:InspectTree`). The buffer's actual parser is started
-- explicitly in after/ftplugin/promptmd.lua -- nvim-treesitter main's own
-- auto-enable autocmd in plugin/40_plugins.lua matches the PLAIN 'markdown'
-- pattern, which (verified) does not fire for the compound filetype
-- 'markdown.promptmd' at all, so there's no race to win there.
vim.treesitter.language.register("promptmd", "markdown.promptmd")

vim.filetype.add({
  extension = {
    j2 = "jinja2",
    jinja = "jinja2",
    jinja2 = "jinja2",
    yaml = "yaml.jinja2",
    yml = "yaml.jinja2",
    md = detect_markdown_variant,
    xmd = detect_markdown_variant,
  },
  pattern = {
    -- Helm (higher priority than default yaml.jinja2)
    [".*/templates/.*%.ya?ml"] = "helm",
    [".*/templates/.*%.tpl"] = "helm",
    ["helmfile.*%.ya?ml"] = "helm",
  },
})
