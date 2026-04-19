-- ┌──────────────────────────┐
-- │ Neovide GUI configuration │
-- └──────────────────────────┘
--
-- Settings and keymaps that only apply when running inside Neovide.
-- All logic is guarded by `vim.g.neovide` so plain `nvim` is unaffected.

if not vim.g.neovide then
  return
end

-- GUI font (edit to taste; Neovide needs an explicit guifont to size).
-- Fallback chain keeps it working even if the first font isn't installed.
vim.o.guifont = "JetBrainsMono Nerd Font,Fira Code,monospace:h11"

-- Visual tweaks
vim.g.neovide_cursor_animation_length = 0.03
vim.g.neovide_cursor_trail_size       = 0.2
vim.g.neovide_scroll_animation_length = 0.15
vim.g.neovide_refresh_rate            = 60
vim.g.neovide_remember_window_size    = true
vim.g.neovide_input_use_logo          = true -- Enable <D-*> (Super/Cmd) mappings

-- ─── Transparency (background-only; glyphs stay opaque) ────────────────────
-- neovide_normal_opacity dims ONLY the Normal hl background, unlike
-- neovide_opacity which dims the whole window including text. Mirrors the
-- prior visual intent we had via picom, without washing out the font.
--   https://neovide.dev/configuration.html#transparency
--
-- For the alpha to actually composite through to the desktop, the Normal
-- highlight group's background must not be fully opaque. Most colorschemes
-- paint `Normal bg = "#xxxxxx"` (alpha 255), which defeats normal_opacity in
-- practice. We explicitly clear Normal.bg (and a few related groups) on load
-- and again on every ColorScheme change so the setting actually shows.
vim.g.neovide_opacity        = 1.0   -- whole-window alpha (keep full)
vim.g.neovide_normal_opacity = 0.625 -- Normal-bg alpha (background-only)

local function clear_bg()
  for _, group in ipairs({
    "Normal", "NormalNC", "NormalFloat",
    "SignColumn", "EndOfBuffer", "LineNr",
  }) do
    pcall(vim.api.nvim_set_hl, 0, group, { bg = "NONE" })
  end
end

-- Apply now (after startup so the colorscheme has already loaded) and on
-- every subsequent colorscheme switch.
vim.schedule(clear_bg)
vim.api.nvim_create_autocmd("ColorScheme", {
  group    = vim.api.nvim_create_augroup("NeovideTransparent", { clear = true }),
  callback = clear_bg,
  desc     = "Neovide: keep Normal bg transparent so normal_opacity composites",
})

local focus_group = vim.api.nvim_create_augroup("NeovideFocusOpacity", { clear = true })
vim.api.nvim_create_autocmd("FocusGained", {
  group = focus_group,
  callback = function() vim.g.neovide_normal_opacity = 0.625 end,
  desc = "Neovide: restore focused background opacity",
})
vim.api.nvim_create_autocmd("FocusLost", {
  group = focus_group,
  callback = function() vim.g.neovide_normal_opacity = 0.5 end,
  desc = "Neovide: dim background when unfocused",
})

-- Clipboard: make Ctrl+Shift+C / Ctrl+Shift+V match terminal behavior
vim.keymap.set({ "n", "v" }, "<C-S-c>", '"+y',  { desc = "Copy to system clipboard" })
vim.keymap.set({ "n", "v" }, "<C-S-v>", '"+p',  { desc = "Paste from system clipboard" })
vim.keymap.set("i",          "<C-S-v>", "<C-r>+", { desc = "Paste from system clipboard" })
vim.keymap.set("c",          "<C-S-v>", "<C-r>+", { desc = "Paste from system clipboard" })
vim.keymap.set("t",          "<C-S-v>", [[<C-\><C-n>"+pi]], { desc = "Paste from system clipboard" })

-- ─── Zoom (scale factor) ────────────────────────────────────────────────────
vim.g.neovide_scale_factor = vim.g.neovide_scale_factor or 1.0

local function change_scale(delta)
  local cur = vim.g.neovide_scale_factor or 1.0
  local next_scale = cur + delta
  -- Clamp so we don't zoom into oblivion or disappear
  if next_scale < 0.4 then next_scale = 0.4 end
  if next_scale > 4.0 then next_scale = 4.0 end
  vim.g.neovide_scale_factor = next_scale
  vim.notify(string.format("Neovide scale: %.2f", next_scale), vim.log.levels.INFO)
end

local function reset_scale()
  vim.g.neovide_scale_factor = 1.0
  vim.notify("Neovide scale: 1.00", vim.log.levels.INFO)
end

-- Ctrl + = / + : zoom in (both variants for keyboards w/ or w/o shift for "+")
vim.keymap.set({ "n", "i", "v", "t" }, "<C-=>", function() change_scale( 0.1) end,
  { desc = "Neovide zoom in" })
vim.keymap.set({ "n", "i", "v", "t" }, "<C-+>", function() change_scale( 0.1) end,
  { desc = "Neovide zoom in" })

-- Ctrl + - : zoom out
vim.keymap.set({ "n", "i", "v", "t" }, "<C-->", function() change_scale(-0.1) end,
  { desc = "Neovide zoom out" })
vim.keymap.set({ "n", "i", "v", "t" }, "<C-_>", function() change_scale(-0.1) end,
  { desc = "Neovide zoom out" })

-- Ctrl + 0 : reset zoom to 1.0
vim.keymap.set({ "n", "i", "v", "t" }, "<C-0>", reset_scale,
  { desc = "Neovide reset zoom" })

-- Ctrl + ScrollWheel : zoom with mouse
vim.keymap.set({ "n", "i", "v", "t" }, "<C-ScrollWheelUp>",   function() change_scale( 0.1) end,
  { desc = "Neovide zoom in (wheel)" })
vim.keymap.set({ "n", "i", "v", "t" }, "<C-ScrollWheelDown>", function() change_scale(-0.1) end,
  { desc = "Neovide zoom out (wheel)" })

-- ─── Auto-open :terminal on startup ────────────────────────────────────────
-- When launching neovide with no file arguments, drop straight into a
-- :terminal in insert mode. Running `nvim <file>` still opens the file
-- normally. Schedule the terminal call so it runs AFTER mini.starter (or
-- any other VimEnter dashboard) has populated the initial window; :terminal
-- then replaces whatever buffer is currently showing.
vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("NeovideAutoTerminal", { clear = true }),
  desc  = "Neovide: auto-run :terminal when no args were passed",
  callback = function()
    if vim.fn.argc() ~= 0 then return end
    vim.schedule(function()
      vim.cmd("terminal")
      vim.cmd("startinsert")
    end)
  end,
})
