-- Telescope picker for icarus provider/model IDs.
--
-- Data source: GET http://127.0.0.1:7654/provider via lua/icarus_models.lua
-- (shared with the `models` markdown snippet -- not duplicated here). Falls
-- back to a small static list if icarus serve is unreachable so this never
-- hard-errors; the fallback may go stale and is only ever a last resort.
--
-- Usage: require('icarus_model_picker').pick()
-- Wired to auto-open on the r2-d2 snippet family's `model:` tabstop via the
-- MiniSnippetsSessionJump autocmd in plugin/30_mini.lua (sentinel: PICK_MODEL).

local M = {}

-- Last-known-good snapshot, used only when the live fetch fails.
local fallback_entries = {
  'anthropic/claude-fable-5',
  'anthropic/claude-opus-4-8',
  'openai-codex/gpt-5.5',
  'vllm-monty-laguna/qwen3.6-35b-a3b',
}

--- Open the provider/model telescope picker.
---@param opts table|nil `{ on_select = function(display_string) }`.
---  Defaults to inserting the selected string at the cursor position.
function M.pick(opts)
  opts = opts or {}
  local has_telescope = pcall(require, 'telescope')
  if not has_telescope then
    vim.notify('telescope.nvim is required for the icarus model picker', vim.log.levels.ERROR)
    return
  end

  local icarus_models = require('icarus_models')
  local data = icarus_models.fetch()
  local entries = data and icarus_models.flatten(data) or fallback_entries
  if data == nil then
    vim.notify(
      string.format('icarus serve not running at %s -- showing static fallback list', icarus_models.addr),
      vim.log.levels.WARN
    )
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')

  local on_select = opts.on_select
    or function(value)
      local pos = vim.api.nvim_win_get_cursor(0)
      local row, col = pos[1], pos[2]
      local line = vim.api.nvim_get_current_line()
      vim.api.nvim_set_current_line(line:sub(1, col) .. value .. line:sub(col + 1))
      vim.api.nvim_win_set_cursor(0, { row, col + #value })
    end

  pickers
    .new({}, {
      prompt_title = 'icarus provider/model' .. (data == nil and ' (fallback, serve unreachable)' or ''),
      finder = finders.new_table({ results = entries }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then on_select(selection[1]) end
        end)
        return true
      end,
    })
    :find()
end

--- Replace the first occurrence of `sentinel` on the current line with the
--- picked provider/model string. Used by the mini.snippets tabstop wiring,
--- where the sentinel occupies the `model:` tabstop's placeholder span.
---@param sentinel string|nil Defaults to 'PICK_MODEL'.
function M.pick_replace_sentinel(sentinel)
  sentinel = sentinel or 'PICK_MODEL'
  M.pick({
    on_select = function(value)
      local line = vim.api.nvim_get_current_line()
      local s, e = line:find(sentinel, 1, true)
      if not s then return end
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_set_current_line(line:sub(1, s - 1) .. value .. line:sub(e + 1))
      vim.api.nvim_win_set_cursor(0, { row, s - 1 + #value })
    end,
  })
end

return M
