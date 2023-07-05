return {
    settings =  {
        Lua = {
            diagnostics = {
                globals = { "vim" },
            },
            workspaces = {
                library = {
                    [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                    [vim.fn.stdpath("config") .. "/lua"] = true,
                },
            },
        },
    },
}
