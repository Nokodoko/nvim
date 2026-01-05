-- ┌────────────────────────┐
-- │ Custom Neovim behavior │
-- └────────────────────────┘
--
-- Options ====================================================================
local opt = vim.o
opt.clipboard = vim.env.SSH_CONNECTION and "" or "unnamedplus" -- Sync with system clipboard
opt.cursorline = true -- Enable highlighting of the current line
opt.foldlevel = 99
opt.list = true -- Show some invisible characters (tabs...
opt.relativenumber = true -- Relative line numbers
opt.undolevels = 10000
opt.jumpoptions = "view"
opt.laststatus = 3 -- global statusline
opt.shiftwidth = 2 -- Size of an indent
opt.wrap = false -- Disable line wrap
opt.tabstop = 2 -- Number of spaces tabs count for
opt.splitright = true -- Put new windows right of current
opt.splitbelow = true -- Put new windows below current
opt.signcolumn = "yes" -- Always show the signcolumn, otherwise it would shift the text each time
opt.sidescrolloff = 8 -- Columns of context
opt.scrolloff = 4 -- Lines of context
opt.pumheight = 10 -- Maximum number of entries in a popup
opt.pumblend = 10 -- Popup blend

opt.termguicolors = true -- True color support
