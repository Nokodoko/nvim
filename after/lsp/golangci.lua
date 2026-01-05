return {
  default_config = {
    cmd = { 'golangci-lint-langserver' },
    filetypes = { 'go', 'gomod' },
    init_options = {
      command = { 'golangci-lint', 'run', '--out-format', 'json' },
    },
    root_dir = function(fname)
      return require('lspconfig').util.root_pattern(
        '.golangci.yml',
        '.golangci.yaml',
        '.golangci.toml',
        '.golangci.json',
        'go.work',
        'go.mod',
        '.git'
      )(fname)
    end,
  },
}