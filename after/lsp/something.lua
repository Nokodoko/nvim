return {                                                                          
│ -- lspconfig                                                                    
│ {                                                                               
│ │ "neovim/nvim-lspconfig",                                                      
│ │ event = "LazyFile",
│ │ ft = { "terraform" },                                                           
│ │ dependencies = {                                                              
│ │ │ "mason.nvim",                                                               
│ │ │ { "mason-org/mason-lspconfig.nvim", config = function() end },              
│ │ },                                                                            
│ │ opts_extend = { "servers.*.keys" },                                           
│ │ opts = function()                                                             
│ │ │ ---@class PluginLspOpts                                                     
│ │ │ local ret = {                                                               
│ │ │ │ -- options for vim.diagnostic.config()                                    
│ │ │ │ ---@type vim.diagnostic.Opts                                              
│ │ │ │ diagnostics = {                                                           
│ │ │ │ │ underline = true,                                                       
│ │ │ │ │ update_in_insert = false,                                               
│ │ │ │ │ virtual_text = {                                                        
│ │ │ │ │ │ spacing = 4,                                                          
│ │ │ │ │ │ source = "if_many",                                                   
│ │ │ │ │ │ prefix = "●",                                                         
│ │ │ │ │ │ -- this will set set the prefix to a function that returns the diagno 
│ │ │ │ │ │ -- prefix = "icons",                                                  
│ │ │ │ │ },                                                                      
│ │ │ │ │ severity_sort = true,                                                   
│ │ │ │ │ signs = {                                                               
│ │ │ │ │ │ text = {                                                              
│ │ │ │ │ │ │ [vim.diagnostic.severity.ERROR] = LazyVim.config.icons.diagnostics.E
│ │ │ │ │ │ │ [vim.diagnostic.severity.WARN] = LazyVim.config.icons.diagnostics.W 
│ │ │ │ │ │ │ [vim.diagnostic.severity.HINT] = LazyVim.config.icons.diagnostics.H 
│ │ │ │ │ │ │ [vim.diagnostic.severity.INFO] = LazyVim.config.icons.diagnostics.I 
│ │ │ │ │ │ },                                                                    
│ │ │ │ │ },                                                                      
│ │ │ │ },                                                                        
│ │ │ │ -- Enable this to enable the builtin LSP inlay hints on Neovim.           
│ │ │ │ -- Be aware that you also will need to properly configure your LSP server 
│ │ │ │ -- provide the inlay hints.                                               
│ │ │ │ inlay_hints = {                                                           
│ │ │ │ │ enabled = true,                                                         
│ │ │ │ │ exclude = { "vue" }, -- filetypes for which you don't want to enable in 
│ │ │ │ },                                                                        
│ │ │ │ -- Enable this to enable the builtin LSP code lenses on Neovim.           
                                                        y  Top   1:1    16:32  

