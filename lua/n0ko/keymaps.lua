local opts = { noremap = true, silent = true }

local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

--Remap space as leader key
keymap("", " ", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Modes
--   normal_mode = "n",
--   insert_mode = "i",
--   visual_mode = "v",
--   visual_block_mode = "x",
--   term_mode = "t",
--   command_mode = "c",

-- Normal --
-- Better window navigation
--keymap ("n",  "<C-h>",            "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>h", opts)
keymap("n", "<C-k>", "<C-w>l", opts)
--keymap ("n",  "<C-l>",            "<C-w>l", opts)
keymap("n", "<BS>", ":bd<cr>", opts)
keymap("n", "<leader>o", ":set ma<cr>", opts)
keymap("n", "<leader><F2>", ":split term://cmus<cr>", opts)
keymap("n", "<leader>s", ":SemanticHighlightToggle<cr>", opts)
keymap("n", "<leader><C-Space>", ":vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>a", opts)
keymap("n", "<leader><Right>", ":vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>a", opts)
keymap("n", "<leader>z", ":split term://tty-clock -c<cr>:set number!<cr>:set relativenumber!<cr>:", opts)
keymap("n", "<esc>", "A", opts)
keymap("n", "'", "cw", opts)
keymap("n", "<C-'>", "dw<esc><esc>", opts)
keymap("n", "<Up>", ":Telescope live_grep theme=ivy<cr>", opts)
keymap("n", "<F3>", ":w!<cr>", opts)
keymap("n", "Q", ":q!<cr>", opts)
keymap("n", "<c-f>", ":RnvimrToggle<cr>", opts)
keymap("n", "<leader><leader>w", ":VimwikiIndex<cr>", opts)
keymap("n", "<leader><leader>x", ":! chmod +x ./%<cr>", opts)
--keymap("n", "<leader>D", ":require('duck'.hatch("", 1) end, {})<cr>", opts)

--Plugin Binds
keymap("n", "<F8>", ":TagbarToggle<CR>", opts)
keymap("n", "<leader>g", ":LazyGit<cr>", opts)
keymap("n", "<leader>t", ":TableModeEnable<cr>", opts)
keymap("n", "<leader>d", ":TableModeDisable<cr>", opts)
keymap(
    "n",
    "<leader>q",
    ":term://gtop<cr>:set number!<cr>:set relativenumber!<cr>:vsplit term://glances<cr>:set number!<cr>:set relativenumber!<cr>",
    opts
)
keymap(
    "n",
    "<leader>3",
    ":vsplit term://tty-clock -c<cr>:set number!<cr>:set relativenumber!<cr>:split term://zsh<cr>:split term://cmus<cr><esc><C-w>h<C-w>h",
    opts
)
keymap(
    "n",
    "<F12>",
    ":vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>:vsplit term://tty-clock -c<cr>:split term://cmus<cr>:split term://calcurse<cr><C-W>h<C-W>h",
    opts
)
keymap(
    "n",
    "<leader>1",
    ":vsplit term://zsh<cr>:set number!<cr>:set relativenumber!<cr>:vsplit term://neomutt<cr><cr>:vsplit term://glances<cr>:split term://gtop<cr>:split term://cmus<cr>:vsplit term://calcurse<cr><C-W>k<C-W>k:vsplit term://tty-clock -cs<cr><C-w>h<C-w>h<C-w>h",
    opts
)
keymap("n", "<leader>m", ":vsplit term://cmus<cr>", opts)

--Standard Commands
keymap("n", "<F9>", ":set hlsearch!<cr>", opts)
keymap("n", "<leader>?", ":Helptags<cr>", opts)

-- Resize with arrows
keymap("n", "<C-Up>", ":resize -2<CR>", opts)
keymap("n", "<C-Down>", ":resize +2<CR>", opts)
keymap("n", "<C-Left>", ":vertical resize -2<CR>", opts)
keymap("n", "<C-Right>", ":vertical resize +2<CR>", opts)

-- Navigate buffers
keymap("n", "<S-h>", ":bnext<CR>", opts)
keymap("n", "<S-l>", ":bprevious<CR>", opts)
keymap("n", "<F6>", "l", opts)
keymap("n", "<F5>", "k", opts)
keymap("n", "<F10>", "h", opts)
keymap("n", "<F4>", "j", opts)

--Chatgpt
--keymap("n", "<leader>c", ":ChatGPTRunCustomCodeAction<cr>", opts)
keymap("v", "<C-e>", ":ChatGPTRun explain_code<cr>", opts)
keymap("v", "<C-f>", ":ChatGPTRun fix_bugs<cr>", opts)
keymap("v", "<C-t>", ":ChatGPTRun add_tests<cr>", opts)

-- Move text up and down
keymap("n", "<A-j>", "<Esc>:m .+1<CR>==gi", opts)
keymap("n", "<A-k>", "<Esc>:m .-2<CR>==gi", opts)

-- Insert --
-- Press jk fast to enter
--keymap ("i", "jk",   "<ESC>",   opts)
keymap("i", "<F3>", "<esc>:w!<cr>", opts)

-- Visual -- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts) --Move text up and down
keymap("v", "<M-J>", ":m .+1<CR>==", opts)
keymap("v", "<M-K>", ":m .-2<CR>==", opts)
keymap("v", "p", '   "_dP', opts)

-- Visual Block --
-- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<Up>", "g<C-a>", opts)

-- Terminal --
-- Better terminal navigation
--keymap( "t", "<M-F10>",  "<C-\><C-n><C-w>h", opts)
--keymap( "t",  "C-t",     "<C-\><C-n>:q!<cr>", opts)
keymap("n", "<Down>", ":split term://zsh<cr>:set number!<cr>:set relativenumber!<cr>:set modifiable<cr>a", opts)
--keymap("n", "<Down>", ":ToggleTerm<cr>", opts)
keymap("n", "<Right>", ":ToggleTerm<cr>", opts)
--keymap("n", "<leader>l", ":TermExec cmd='glances' direction=vertical size=100<cr>", opts)
keymap("n", "<leader>l", "NullLsInfo<cr>", opts)

-- Cmdline Mode
vim.keymap.set("c", "<S-Enter>", function()
    require("noice").redirect(vim.fn.getcmdline())
end, { desc = "Redirect Cmdline" })
-- keymap ("t", "<C-h>", "<C-\\><C-N><C-w>h", term_opts)
-- keymap ("t", "<C-j>", "<C-\\><C-N><C-w>j", term_opts)
-- keymap ("t", "<C-k>", "<C-\\><C-N><C-w>k", term_opts)
-- keymap ("t", "<C-l>", "<C-\\><C-N><C-w>l", term_opts)
