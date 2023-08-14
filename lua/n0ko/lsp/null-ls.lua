local null_ls_status_ok, null_ls = pcall(require, "null-ls")
if not null_ls_status_ok then
    return
end

-- CLIENT BUILTINS
local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics
local code_actions = null_ls.builtins.code_actions
local hover = null_ls.builtins.hover
local spelling = null_ls.builtins.completion.spell
--local methods = null_ls.utils.methods.request_name_to_capability

local defaults = {
    border = nil,
    globals = { 'vim' },
    cmd = { "nvim" },
    debounce = 250,
    debug = false,
    default_timeout = 5000,
    diagnostic_config = nil,
    diagnostics_format = "#{m}",
    fallback_severity = vim.diagnostic.severity.ERROR,
    log_level = "warn",
    notify_format = "[null-ls] %s",
    on_attach = nil,
    on_init = nil,
    on_exit = nil,
    root_dir = require("null-ls.utils").root_pattern(".null-ls-root", "Makefile", ".git"),
    should_attach = nil,
    sources = nil,
    temp_dir = nil,
    update_in_insert = false,
}

null_ls.setup({
    debug = true,
    --    actions = null_ls.buildin.code_actions,
    sources = {
        -- FORMATTING --
        formatting.shfmt.with({
            filetypes = { "zsh", "sh" }
        }),
        formatting.prettier.with({
            extra_args = { "--no-semi", "--single-quote", "--jsx-single-quote" },
            filetypes =  { "html", "json", "yaml", "markdown", "toml" },
        }),
        formatting.black.with({ extra_args = { "--fast" } }),
        formatting.stylua,
        formatting.rustfmt.with({
            filetypes = { "rust" },
            init = function ()
                vim.g.rustfmt_autosave = 1
            end
        }),
        formatting.dprint.with({
            filetypes = { "rust" }
        }),
        -- DIAGNOSTICS --
        diagnostics.shellcheck.with({
            filetypes = { "zsh", "sh" },
        }),
        diagnostics.yamllint.with({
            filetypes = { "yaml", "yml", },
        }),
        --diagnostics.flake8,
        --methods.find_references,
        hover.dictionary,
        --misspell.with({ filetypes = { "markdown", "txt", "wiki" }, args = { "$FILENAME" } }),
        ----completion.spell,
        --code_actions.filler,
        spelling,
        hover.dictionary,
    },
})

null_ls.setup({ sources = sources })

--null-ls.setup(setup)
