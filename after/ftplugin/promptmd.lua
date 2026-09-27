-- ┌──────────────────────────────┐
-- │ promptmd filetype config     │
-- └──────────────────────────────┘
--
-- Loaded whenever 'filetype' is "markdown.promptmd" -- nvim splits a
-- compound filetype on '.' and sources the ftplugin for EACH component
-- (verified: after/ftplugin/markdown.lua loads first, this loads second),
-- so plain markdown ftplugins/snippets keep working here too.
--
-- nvim-treesitter main's own auto-enable autocmd (plugin/40_plugins.lua)
-- only matches the plain 'markdown' FileType pattern, which does not fire
-- for this compound filetype (verified with nvim_create_autocmd -- compound
-- filetypes are NOT split for ordinary autocmd pattern matching, only for
-- the built-in ftplugin loader). So nothing else starts a parser for this
-- buffer; start promptmd explicitly.
vim.treesitter.start(0, 'promptmd')

vim.cmd('setlocal foldmethod=expr foldexpr=v:lua.vim.treesitter.foldexpr()')

-- Buffer-local mini.ai textobject: `aT`/`iT` select around/inside a
-- promptmd element (tag pair + its content), mirroring the treesitter
-- textobject spec pattern already used for `F` (function) in
-- plugin/30_mini.lua's mini.ai custom_textobjects.
local ok, ai = pcall(require, 'mini.ai')
if ok then
  vim.b.miniai_config = {
    custom_textobjects = {
      T = ai.gen_spec.treesitter({ a = '@block.outer', i = '@block.inner' }),
    },
  }
end

-- Markup tag editing (see lua/xml_surround.lua). after/ftplugin/markdown.lua
-- has already run for this compound filetype and registered its own `L`
-- surrounding, which `setup_buffer()` preserves by merging into the existing
-- `vim.b.minisurround_config` rather than replacing it.
require('xml_surround').setup_buffer()
