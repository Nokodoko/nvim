-- ┌──────────────────────┐
-- │ html filetype config │
-- └──────────────────────┘
--
-- There is no html formatter or html LSP in this config, so tag editing is
-- handled entirely in-editor. See lua/xml_surround.lua for both mechanisms:
-- typing the `>` of an opening tag explodes it into three lines, and visual
-- `sat` wraps a selection in an empty tag pair whose name is typed once.
require('xml_surround').setup_buffer()
