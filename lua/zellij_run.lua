-- Zellij floating pane runner module
local M = {}

-- Store the buffer number that invoked the plugin
M.invoking_bufnr = nil

-- Get visually selected text
function M.get_visual_selection()
  -- Get the saved visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  -- Get lines from buffer
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  if #lines == 0 then return nil end

  -- Handle single line vs multi-line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, '\n')
end

-- Run command in Zellij floating pane
function M.run_in_zellij(interpreter)
  -- Store invoking buffer
  M.invoking_bufnr = vim.api.nvim_get_current_buf()

  local selection = M.get_visual_selection()
  if not selection or selection == '' then
    M.write_error('No text selected')
    return
  end

  -- Build zellij command with top-right positioning
  -- No --close-on-exit to allow interactive commands
  local zellij_cmd = string.format(
    'zellij run --floating --x 50%% --y 0 --width 50%% --height 70%% -- %s -c %s',
    interpreter,
    vim.fn.shellescape(selection)
  )

  -- Run asynchronously using jobstart
  vim.fn.jobstart(zellij_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          M.write_error(string.format('Zellij error (exit %d)', exit_code))
        end)
      end
    end,
  })
end

-- Write error message to the invoking buffer
function M.write_error(msg)
  if M.invoking_bufnr and vim.api.nvim_buf_is_valid(M.invoking_bufnr) then
    local lines = vim.split('-- ERROR: ' .. msg, '\n')
    local line_count = vim.api.nvim_buf_line_count(M.invoking_bufnr)
    vim.api.nvim_buf_set_lines(M.invoking_bufnr, line_count, line_count, false, lines)
  end
end

return M
