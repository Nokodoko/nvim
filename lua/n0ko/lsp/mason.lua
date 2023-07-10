local servers = {
    "bashls",
    "clangd",
--    "codelldb",
    "dockerls",
    "gopls",
    "jedi_language_server",
    "jsonls",
    "lua_ls",
    "pyright",
    "quick_lint_js",
    "rust_analyzer",
    "terraformls",
    "yamlls",
    "zls",
}

local settings = {
    ui = {
        border = "none",
        icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
        },
    },
    log_level = vim.log.levels.INFO,
    max_concurrent_installers = 4,
}

require("mason").setup(settings)
--require("mason-lspconfig").setup()

local lspconfig_status_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status_ok then
    return
end

local opts = {}

for _, server in pairs(servers) do
    opts = {
        on_attach = require("n0ko.lsp.handlers").on_attach,
        capabilities = require("n0ko.lsp.handlers").capabilities,
    }

    server = vim.split(server, "@")[1]

    local require_ok, conf_opts = pcall(require, "n0ko.lsp.settings" .. server)
    if require_ok then
        opts = vim.tbl_deep_extend("force", conf_opts, opts)
    end

    lspconfig[server].setup(opts)
end
