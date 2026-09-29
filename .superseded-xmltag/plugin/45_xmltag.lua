-- Wire up 'xmltag': insert-mode XML/HTML/markdown tag auto-close (`>`) and
-- vim-surround-style tag wrapping (visual `sat`). See lua/xmltag.lua for the
-- module itself.
--
-- Loaded eagerly (like plugin/50_path_completion.lua's autocmd, not wrapped
-- in later()/now()): setup() only registers one FileType autocmd, no plugin
-- dependency and negligible startup cost. mini.surround (later()-loaded in
-- plugin/30_mini.lua) only needs to exist by the time a buffer actually
-- presses `sat`, not by the time this file runs.
require('xmltag').setup()
