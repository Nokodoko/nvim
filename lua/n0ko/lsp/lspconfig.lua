local status_ok, lspconfig = pcall(require,'nvim-lspconfig')
if not status_ok then
    return
end

lspconfig {}

---- RUST --
--lspconfig.rust_analyzer.setup{
--    settings = {
--        ['rust_analyzer'] = {},
--    },
--}
