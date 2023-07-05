local M = {}

_ConfigValues = {
  on_attach = function(client, bufnr)
      -- your on_attach will be called at end of navigator on_attach
  end,
}


M.setup = function ()
   vim.cmd([[autocmd Filetype, Bufenter * lua require'lspclient.clients'.on_filetype()]]) 
    print("Lsp loading")
    require('lsp.lazyloader').init()
    -- ADD CONFIG VALUES IN SETUP FUNCTION BELOW --
    require('lsp.lspclient.clients').setup()
--        
end

return M
