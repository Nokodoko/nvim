-- Claude prompt module - main entry point
local M = {}

local api = require('claude_prompt.api')
local context = require('claude_prompt.context')

-- Setup function to configure the API module
function M.setup(opts)
  api.setup(opts)
end

-- Insert response text directly into buffer after cursor line
local function insert_response(target_buf, target_line, response_text)
  local lines = vim.split(response_text, '\n', { plain = true })
  vim.api.nvim_buf_set_lines(target_buf, target_line, target_line, false, lines)
end

-- Internal helper to prompt via vim.ui.input (rendered by noice at cursor)
local function open_prompt(include_selection)
  if api.is_busy() then
    vim.notify('Claude is already processing a request', vim.log.levels.WARN)
    return
  end

  -- Save original buffer and cursor before prompt opens
  local target_buf = vim.api.nvim_get_current_buf()
  local target_line = vim.api.nvim_win_get_cursor(0)[1]

  vim.ui.input({ prompt = api.get_model_name() .. ': ' }, function(input)
    if not input or input == '' then return end

    local ctx = context.gather({
      include_file = true,
      include_cursor = true,
      include_treesitter = true,
      include_symbols = false,
      include_selection = include_selection,
    })

    vim.notify('Claude: Thinking...', vim.log.levels.INFO)

    api.request(input, ctx, function(response_text, err)
      if err then
        vim.notify('Claude: ' .. err, vim.log.levels.ERROR)
        return
      end

      if response_text and response_text ~= '' then
        insert_response(target_buf, target_line, response_text)
      else
        vim.notify('Claude returned an empty response', vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Main prompt function - prompts Claude with current buffer context
function M.prompt()
  open_prompt(false)
end

-- Prompt with visual selection context
function M.prompt_visual()
  open_prompt(true)
end

-- Cancel in-flight request
M.cancel = api.cancel

-- Insert the last Claude Code response into the current buffer
-- Reads from /tmp/claude_last_response.md (written by Stop hook)
function M.insert_last_response()
  local response_file = '/tmp/claude_last_response.md'
  local meta_file = '/tmp/claude_last_response.meta.json'

  -- Check if response file exists
  if vim.fn.filereadable(response_file) ~= 1 then
    vim.notify('No Claude response found. Run a Claude Code prompt first.', vim.log.levels.WARN)
    return
  end

  -- Read the response text
  local lines = vim.fn.readfile(response_file)
  if #lines == 0 then
    vim.notify('Claude response file is empty.', vim.log.levels.WARN)
    return
  end

  -- Check total character count to detect trivial captures
  local total_chars = 0
  for _, line in ipairs(lines) do
    total_chars = total_chars + #line
  end

  if total_chars < 200 then
    -- Warn but still insert -- the user may want it anyway
    vim.notify(
      string.format('Warning: response is only %d chars (may be coordination noise)', total_chars),
      vim.log.levels.WARN
    )
  end

  -- Check staleness via metadata (warn if older than 10 minutes)
  if vim.fn.filereadable(meta_file) == 1 then
    local meta_raw = table.concat(vim.fn.readfile(meta_file), '')
    local ok, meta = pcall(vim.fn.json_decode, meta_raw)
    if ok and meta and meta.timestamp then
      local age = os.time() - meta.timestamp
      if age > 600 then
        local mins = math.floor(age / 60)
        vim.notify(string.format('Claude response is %d min old', mins), vim.log.levels.INFO)
      end
    end
  end

  -- Insert after the current cursor line
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, cursor_line, cursor_line, false, lines)
  vim.notify(string.format('Inserted %d lines from Claude response', #lines), vim.log.levels.INFO)
end

-- Open telescope picker showing recent Claude responses
function M.select_response()
  local history_file = '/tmp/claude_response_history.json'

  if vim.fn.filereadable(history_file) ~= 1 then
    vim.notify('No Claude response history found.', vim.log.levels.WARN)
    return
  end

  local raw = table.concat(vim.fn.readfile(history_file), '')
  local ok, history = pcall(vim.fn.json_decode, raw)
  if not ok or not history or #history == 0 then
    vim.notify('Claude response history is empty.', vim.log.levels.WARN)
    return
  end

  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers = require('telescope.previewers')

  pickers
    .new({}, {
      prompt_title = 'Claude Responses',
      finder = finders.new_table({
        results = history,
        entry_maker = function(entry)
          local age = ''
          if entry.timestamp then
            local secs = os.time() - entry.timestamp
            if secs < 60 then
              age = string.format('%ds ago', secs)
            elseif secs < 3600 then
              age = string.format('%dm ago', math.floor(secs / 60))
            else
              age = string.format('%dh ago', math.floor(secs / 3600))
            end
          end
          local display = string.format('[%s] %s', age, entry.preview or '(empty)')
          return {
            value = entry,
            display = display,
            ordinal = entry.preview or '',
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = previewers.new_buffer_previewer({
        title = 'Response Preview',
        define_preview = function(self, entry)
          local lines = vim.split(entry.value.text or '', '\n', { plain = true })
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.bo[self.state.bufnr].filetype = 'markdown'
        end,
      }),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection and selection.value and selection.value.text then
            local lines = vim.split(selection.value.text, '\n', { plain = true })
            local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
            vim.api.nvim_buf_set_lines(0, cursor_line, cursor_line, false, lines)
            vim.notify(string.format('Inserted %d lines from Claude response', #lines), vim.log.levels.INFO)
          end
        end)
        return true
      end,
    })
    :find()
end

return M
