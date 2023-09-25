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


lspconfig.sumneko_lua.setup {
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = 'LuaJIT',
                -- Setup your 'lua' path
                path = vim.split(package.path, ';'),
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = {'vim'},
            },
            workspace = {
                -- Make the server aware of Neovim runtime files
                library = {
                    [vim.fn.expand('$VIMRUNTIME/lua')] = true,
                    [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true,
                    -- Add your library path here
                    ['/usr/share/lua/5.4/luarocks/fs.lua'] = true
                },
            },
        },
    },
}
