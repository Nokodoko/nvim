local status_ok, fzf_lsp = pcall(require, "fzf_lsp")
if not status_ok then
    return
end

setup = {
    let g:fzf_preview_window = [

    ]
}

fzf_lsp.setup(setup)
