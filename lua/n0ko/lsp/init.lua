local status_ok, _ = pcall(require, "lspconfig")
if not status_ok then
    return
end

require("n0ko.lsp.mason")
require("n0ko.lsp.handlers").setup()
require("n0ko.lsp.null-ls")
require("n0ko.lsp.lspconfig")

