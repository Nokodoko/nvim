local fn = vim.fn

-- Automatically install packer
local install_path = fn.stdpath("data") .. "/site/pack/packer/start/packer.nvim"
if fn.empty(fn.glob(install_path)) > 0 then
    PACKER_BOOTSTRAP = fn.system({
        "git",
        "clone",
        "--depth",
        "1",
        "https://github.com/wbthomason/packer.nvim",
        install_path,
    })
    print("Installing packer close and reopen Neovim...")
    vim.cmd([[packadd packer.nvim]])
end

-- Autocommand that reloads neovim whenever you save the plugins.lua file
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerSync
  augroup end
]])

-- Use a protected call so we don't error out on first use
local status_ok, packer = pcall(require, "packer")
if not status_ok then
    return
end

-- Have packer use a popup window
packer.init({
    display = {
        open_fn = function()
            return require("packer.util").float({ border = "rounded" })
        end,
    },
})

-- Install your plugins here
return packer.startup(function(use)
    -- ui
    use("folke/noice.nvim")
    use("rcarriga/nvim-notify")
    use("munifTanjim/nui.nvim")

    -- My plugins here
    use("wbthomason/packer.nvim") -- Have packer manage itself
    use("nvim-lua/popup.nvim") -- An implementation of the Popup API from vim in Neovim
    use("nvim-lua/plenary.nvim") -- Useful lua functions used ny lots of plugins
    use("windwp/nvim-autopairs") -- Autopairs, integrates with both cmp and treesitter
    use("numToStr/Comment.nvim") -- Easily comment stuff
    use("kyazdani42/nvim-web-devicons")
    use("ryanoasis/vim-devicons")
    use("ThePrimeagen/vim-be-good")
    use("kyazdani42/nvim-tree.lua")
    use("akinsho/bufferline.nvim")
    use("moll/vim-bbye")
    use("nvim-lualine/lualine.nvim")
    use("ahmedkhalf/project.nvim")
    use("akinsho/toggleterm.nvim")
    use("lewis6991/impatient.nvim")
    use("lukas-reineke/indent-blankline.nvim")
    use("goolord/alpha-nvim")
    use("antoinemadec/FixCursorHold.nvim") -- This is needed to fix lsp doc highlight
    use("folke/which-key.nvim")
    use("nvim-telescope/telescope-packer.nvim")
    use("kdheepak/lazygit.nvim")
    use("junegunn/fzf.vim")
    use("jaxbot/semantic-highlight.vim")
    use("majutsushi/tagbar")
    use("https://github.com/kevinhwang91/rnvimr")

    -- Colorschemes
    use("tiagovla/tokyodark.nvim")
    use("folke/tokyonight.nvim")

    --fun
    use("tamton-aquib/duck.nvim")

    -- use "lunarvim/colorschemes" -- A bunch of colorschemes you can try out
    use("lunarvim/darkplus.nvim")
    use("vim-airline/vim-airline")
    use("vim-airline/vim-airline-themes")
    use("vimwiki/vimwiki")

    -- cmp plugins
    use("hrsh7th/nvim-cmp") -- The completion plugin
    use("hrsh7th/cmp-buffer") -- buffer completions
    use("hrsh7th/cmp-path") -- path completions
    use("hrsh7th/cmp-cmdline") -- cmdline completions
    use("saadparwaiz1/cmp_luasnip") -- snippet completions
    use("hrsh7th/cmp-nvim-lsp")
    use("unblevable/quick-scope")
    use("BurntSushi/ripgrep")
    use("dhruvasagar/vim-table-mode")
    use("tpope/vim-surround")
    use("nvim-orgmode/orgmode")
    use("jackMort/ChatGPT.nvim")
    --use("github/copilot.vim")

    --Latex
    use("lervag/vimtex")
    use("donRaphaco/neotex", {'for', 'tex'})
    --rust
    use("rust-lang/rust.vim")
    use("simrat39/rust-tools.nvim")
    -- snippets
    use("L3MON4D3/LuaSnip") --snippet engine
    use("rafamadriz/friendly-snippets") -- a bunch of snippets to use
    --
    --DAP
    use("mfussenegger/nvim-dap")
    -- LSP
    use("williamboman/mason.nvim") -- simple to use language server installer
    use("williamboman/mason-lspconfig.nvim") -- simple to use language server installer
    use("neovim/nvim-lspconfig") -- enable LSP
    use("tamago324/nlsp-settings.nvim") -- language server settings defined in json for
    use({
        "jose-elias-alvarez/null-ls.nvim",
        config = function()
            require("null-ls").setup()
        end,
        requires = { "nvim-lua/plenary.nvim" },
    })
    use("fatih/vim-go") --, { 'do': ':GoUpdateBinaries' }
    use({ "ray-x/navigator.lua", requires = { "ray-x/guihua.lua", run = "cd lua/fzy && make" } })
    use("ray-x/lsp_signature.nvim")
    use("gfanto/fzf-lsp.nvim")
    use("someone-stole-my-name/yaml-companion.nvim")
    use("ray-x/aurora")

    -- Telescope
    use("nvim-telescope/telescope.nvim")
    use({
        "nvim-telescope/telescope-fzf-native.nvim",
        run = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
    })

    -- Treesitter
    use({
        "nvim-treesitter/nvim-treesitter",
        run = ":TSUpdate",
    })
    use("nvim-treesitter/playground")
    use("JoosepAlviste/nvim-ts-context-commentstring")

    -- Git
    use("lewis6991/gitsigns.nvim")
    use("tpope/vim-fugitive")

    --diff
    use("junkblocker/patchreview-vim")


    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if PACKER_BOOTSTRAP then
        require("packer").sync()
    end
end)
-- test
