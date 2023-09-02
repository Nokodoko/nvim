local status_ok, lspconfig = pcall(require,'nvim-lspconfig')
if not status_ok then
    return
end

-- RUST --
lspconfig.rust_analyzer.setup{
    settings = {
        ['rust_analyzer'] = {},
    },
}


lspconfig.lua_language_server.setup{
    settings = {
        diagnostics = {
            globals = { 'vim' }
        }
    }
}
