-- vim:fileencoding=utf-8:ft=lua:foldmethod=marker
--base config
require("n0ko.options")
require("n0ko.plugins")
require("neodev").setup()
--
--plugin feedback loop
require("n0ko.globals")

--FUN {{{
require("guihua.maps").setup({
    maps = {
        close_view = '<C-x>'
    }
})
--}}}

--keys
require("n0ko.keymaps")
require("n0ko.autocommands")
require("n0ko.whichkey")
--
--lsp
require("n0ko.lsp")
require("n0ko.cmp")
require("n0ko.treesitter")
--require("n0ko.lsp.null-ls")
require("n0ko.lsp.handlers").setup()
----
----bling
require("n0ko.alpha")
require("n0ko.telescope")
require("n0ko.autopairs")
require("n0ko.lualine")
require("n0ko.noice")
require("n0ko.notify")
require("nvim-web-devicons").get_icons()
require("n0ko.bufferline")
----
----git
require("n0ko.gitsigns")
----
----formatting
require("n0ko.comment")
--require("n0ko.indentline")
require("n0ko.toggleterm")
require("n0ko.project")
require("n0ko.impatient")
require("n0ko.P")
require("n0ko.chatgpt")
require("n0ko.nvim-tree")
--require("telescope").load_extension("packer")
