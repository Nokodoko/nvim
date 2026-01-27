-- Tests for zellij_run plugin
-- Run with: nvim --headless -c "luafile plugin/zellij_run_test.lua" -c "qa!"

local function test_get_visual_selection()
  -- Create test buffer with content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'echo hello world', 'echo line 2'})

  -- Simulate visual selection (line 1, cols 1-17)
  vim.fn.setpos("'<", {0, 1, 1, 0})
  vim.fn.setpos("'>", {0, 1, 17, 0})

  local M = require('zellij_run')
  local selection = M.get_visual_selection()

  assert(selection == 'echo hello world', 'Expected "echo hello world", got: ' .. tostring(selection))
  print('PASS: test_get_visual_selection')

  vim.api.nvim_buf_delete(buf, {force = true})
end

local function test_multiline_selection()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'first line', 'second line', 'third line'})

  -- Simulate selection from line 1 col 1 to line 2 col 11
  vim.fn.setpos("'<", {0, 1, 1, 0})
  vim.fn.setpos("'>", {0, 2, 11, 0})

  local M = require('zellij_run')
  local selection = M.get_visual_selection()

  assert(selection == 'first line\nsecond line', 'Expected multiline selection, got: ' .. tostring(selection))
  print('PASS: test_multiline_selection')

  vim.api.nvim_buf_delete(buf, {force = true})
end

local function test_write_error()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'original content'})

  local M = require('zellij_run')
  M.invoking_bufnr = buf
  M.write_error('test error message')

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(#lines == 2, 'Expected 2 lines, got ' .. #lines)
  assert(lines[2]:match('ERROR'), 'Expected error message in buffer')
  print('PASS: test_write_error')

  vim.api.nvim_buf_delete(buf, {force = true})
end

-- Run tests
local ok, err = pcall(function()
  test_get_visual_selection()
  test_multiline_selection()
  test_write_error()
end)

if ok then
  print('All tests passed!')
else
  print('TEST FAILED: ' .. tostring(err))
  vim.cmd('cq 1')
end
