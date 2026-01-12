-- Install the terraform language server using your package manager or following the upstream installation instructions
-- Define a configuration for the terraformls LSP client
return {
vim.lsp.config['terraformls'] = {
  -- Command and arguments to start the server
  cmd = { 'terraform-ls' },
  -- Filetypes to automatically attach to
  filetypes = { 'terraform' },
  -- Sets the "root directory" to the parent directory of the file in the current buffer that contains a ".git" file
  root_markers = { '.git' },
  -- Additional capabilities for the LSP client
  capabilities = {
    textDocument = {
      semanticTokens = {
        multilineTokenSupport = true,
      }
    }
  },
  -- Function to be executed when the LSP client attaches
  on_attach = function(client, bufnr)
    -- Your existing LspAttach logic moved here
    if client.supports_method('textDocument/implementation') then
      -- Create a keymap for vim.lsp.buf.implementation ...
    end
    -- Enable auto-completion
    if client.supports_method('textDocument/completion') then
      vim.lsp.completion.enable(true, client.id, bufnr, {autotrigger = true})
    end
    -- Auto-format ("lint") on

continue
save
    if not client.supports_method('textDocument/willSaveWaitUntil') and client.supports_method('textDocument/formatting') then
      vim.api.nvim_create_autocmd('BufWritePre', {
        group = 'my.lsp_formatting',
        pattern = '<buffer>',
        callback = function()
          vim.lsp.buf.formatting_sync(nil, 1000)
        end,
      })
    end
  end,
}
-- Enable the terraformls configuration
vim.lsp.enable('terraformls')
}

-- -- Configure terraformls LSP client
-- require('lspconfig').terraformls.setup {
--   -- Server capabilities, e.g., semantic tokens support
--   capabilities = {
--     textDocument = {
--       semanticTokens = {
--         multilineTokenSupport = true,
--       }
--     }
--   },
--   vim.lsp.enable{
--   -- Use vim.filetype.add for more idiomatic filetype detection
--   vim.filetype.add({
--     extension = {
--       tf = '.tf',
--       tfvars = 'terraform',
--       hcl = 'hcl',
--     },
--   })
--   }
--   -- Markers to identify the project root for the language server
--   root_markers = {'.tf'},
--   -- on_attach is called when the LSP client successfully attaches to a buffer
--   on_attach = function(client, bufnr)
--     -- Enable auto-completion for the buffer
--     if client:supports_method('textDocument/completion') then
--       vim.lsp.completion.enable(true, client.id, bufnr, {autotrigger = true})
--     end
--
--     -- Auto-format on save if the server supports it and not using willSaveWaitUntil
--     if not client:supports_method('textDocument/willSaveWaitUntil')
--         and client:supports_method('textDocument/formatting') then
--       vim.api.nvim_create_autocmd('BufWritePre', {
--         group = vim.api.nvim_create_augroup('my.lsp_formatting_' .. bufnr, {clear=true}), -- Unique group per buffer
--         buffer = bufnr,
--         callback = function()
--           vim.lsp.buf.format({ bufnr = bufnr, timeout_ms = 1000 }) -- Removed client.id as it might not be needed here
--         end,
--       })
--     end
--
--     -- Add any other custom keymaps or configurations here
--     -- Example: vim.keymap.set('n', '<leader>d', vim.lsp.buf.definition, { buffer = bufnr, desc = 'Go to definition' })
--   end,
-- }
--
-- return {
--   cmd = { 'terraform-ls', 'serve' },
--   filetypes = { 'terraform', 'terraform-vars' },
--   root_markers = { '.terraform', '.git' },
-- }
