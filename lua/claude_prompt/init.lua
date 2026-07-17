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

-- Parse ISO timestamp string to unix epoch
local function parse_iso_timestamp(ts)
  if not ts then return nil end
  local y, mo, d, h, mi, s = ts:match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')
  if y then return os.time({ year=y, month=mo, day=d, hour=h, min=mi, sec=s }) end
  return nil
end

-- Strip ANSI escape sequences (terminal colors/formatting)
local function strip_ansi(text)
  return text:gsub('\027%[[%d;]*m', '')
end

-- Extract text from a JSONL message content field (string or array of content blocks)
local function extract_text(content)
  if type(content) == 'string' then return strip_ansi(content) end
  if type(content) ~= 'table' then return nil end
  local parts = {}
  for _, chunk in ipairs(content) do
    if chunk.type == 'text' and chunk.text then
      parts[#parts + 1] = chunk.text
    end
  end
  if #parts > 0 then return table.concat(parts, '\n') end
  return nil
end

-- Scan JSONL session files and collect messages matching a role
-- For 'assistant' role, also captures custom_message records (e.g. intent-gate output)
local function collect_jsonl_entries(files, role, limit)
  local entries = {}
  for _, path in ipairs(files) do
    if #entries >= limit then break end
    local lines = vim.fn.readfile(path)
    for _, line in ipairs(lines) do
      if #entries >= limit then break end
      local ok, record = pcall(vim.fn.json_decode, line)
      if not ok or not record then goto continue end

      local text = nil
      -- Standard message records (user/assistant)
      if record.type == 'message'
        and record.message and record.message.role == role
        and record.message.content then
        text = extract_text(record.message.content)
      -- custom_message records (intent-gate, extensions) count as assistant output
      elseif role == 'assistant' and record.type == 'custom_message'
        and record.content then
        text = strip_ansi(record.content)
      end

      if text and text ~= '' then
        entries[#entries + 1] = {
          timestamp = parse_iso_timestamp(record.timestamp),
          preview = text:sub(1, 80):gsub('\n', ' '),
          text = text,
        }
      end

      ::continue::
    end
  end
  return entries
end

-- Get sorted Pi session files (newest first, ordered by mtime)
local function get_pi_session_files()
  local sessions_dir = vim.fn.expand('~/.pi/agent/sessions')
  if vim.fn.isdirectory(sessions_dir) ~= 1 then
    vim.notify('Pi sessions directory not found: ' .. sessions_dir, vim.log.levels.WARN)
    return nil
  end
  local files = vim.fn.glob(sessions_dir .. '/**/*.jsonl', false, true)
  if #files == 0 then
    vim.notify('No Pi session files found.', vim.log.levels.WARN)
    return nil
  end
  -- Sort by mtime descending so the most-recently-written session is first.
  -- Lexical sort on the path is wrong because the parent directory name
  -- (cwd safepath, e.g. --tmp-pi-runtime-suite---) dominates the timestamp
  -- embedded in the filename, letting stale /tmp test runs outrank the
  -- user's real recent sessions under ~/Programs/...
  local mtimes = {}
  for _, path in ipairs(files) do
    local stat = vim.loop.fs_stat(path)
    mtimes[path] = (stat and stat.mtime and stat.mtime.sec) or 0
  end
  table.sort(files, function(a, b) return mtimes[a] > mtimes[b] end)
  return files
end

-- Get sorted Claude session files (newest first)
local function get_claude_session_files()
  local projects_dir = vim.fn.expand('~/.claude/projects')
  if vim.fn.isdirectory(projects_dir) ~= 1 then
    vim.notify('Claude projects directory not found.', vim.log.levels.WARN)
    return nil
  end
  local files = vim.fn.glob(projects_dir .. '/**/*.jsonl', false, true)
  if #files == 0 then
    vim.notify('No Claude session files found.', vim.log.levels.WARN)
    return nil
  end
  table.sort(files, function(a, b) return a > b end)
  return files
end

-- Insert lines into buffer at cursor and notify
local function insert_lines_at_cursor(lines, source)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, cursor_line, cursor_line, false, lines)
  vim.notify(string.format('Inserted %d lines from %s', #lines, source), vim.log.levels.INFO)
end

-- Insert last Claude response from /tmp/claude_last_response.md (written by Stop hook)
local function insert_last_claude_response()
  local response_file = '/tmp/claude_last_response.md'
  local meta_file = '/tmp/claude_last_response.meta.json'

  if vim.fn.filereadable(response_file) ~= 1 then
    vim.notify('No Claude response found. Run a Claude Code prompt first.', vim.log.levels.WARN)
    return
  end

  local lines = vim.fn.readfile(response_file)
  if #lines == 0 then
    vim.notify('Claude response file is empty.', vim.log.levels.WARN)
    return
  end

  local total_chars = 0
  for _, line in ipairs(lines) do total_chars = total_chars + #line end

  if total_chars < 200 then
    vim.notify(
      string.format('Warning: response is only %d chars (may be coordination noise)', total_chars),
      vim.log.levels.WARN
    )
  end

  if vim.fn.filereadable(meta_file) == 1 then
    local meta_raw = table.concat(vim.fn.readfile(meta_file), '')
    local ok, meta = pcall(vim.fn.json_decode, meta_raw)
    if ok and meta and meta.timestamp then
      local age = os.time() - meta.timestamp
      if age > 600 then
        vim.notify(string.format('Claude response is %d min old', math.floor(age / 60)), vim.log.levels.INFO)
      end
    end
  end

  insert_lines_at_cursor(lines, 'Claude response')
end

-- Insert last Pi response from newest session file
-- Reads all entries from the most recent session and takes the final one
local function insert_last_pi_response()
  local files = get_pi_session_files()
  if not files then return end
  -- Collect all assistant/custom_message entries from newest file only, then take last
  local entries = collect_jsonl_entries({ files[1] }, 'assistant', 9999)
  if #entries == 0 then
    vim.notify('No Pi assistant responses found.', vim.log.levels.WARN)
    return
  end
  local last = entries[#entries]
  local lines = vim.split(last.text, '\n', { plain = true })
  insert_lines_at_cursor(lines, 'Pi response')
end

-- Insert last response: pick agent first
function M.insert_last_response()
  vim.ui.select({ 'Claude', 'Pi' }, { prompt = 'Insert last response from:' }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if choice == 'Claude' then
        insert_last_claude_response()
      else
        insert_last_pi_response()
      end
    end)
  end)
end

-- Open telescope picker showing a list of agent responses
local function open_history_picker(title, history)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local previewers = require('telescope.previewers')

  pickers
    .new({}, {
      prompt_title = title,
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
            vim.notify(string.format('Inserted %d lines', #lines), vim.log.levels.INFO)
          end
        end)
        return true
      end,
    })
    :find()
end

-- Load Claude response history from /tmp/claude_response_history.json
local function load_claude_history()
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
  open_history_picker('Claude Responses', history)
end

-- Load Pi agent responses from ~/.pi/agent/sessions/**/*.jsonl
local function load_pi_history()
  local files = get_pi_session_files()
  if not files then return end
  local entries = collect_jsonl_entries(files, 'assistant', 50)
  if #entries == 0 then
    vim.notify('No Pi assistant responses found.', vim.log.levels.WARN)
    return
  end
  open_history_picker('Pi Responses', entries)
end

-- Load Pi user prompts from ~/.pi/agent/sessions/**/*.jsonl
local function load_pi_prompts()
  local files = get_pi_session_files()
  if not files then return end
  local entries = collect_jsonl_entries(files, 'user', 50)
  if #entries == 0 then
    vim.notify('No Pi user prompts found.', vim.log.levels.WARN)
    return
  end
  open_history_picker('Pi Prompts', entries)
end

-- Load Claude user prompts from ~/.claude/projects/**/*.jsonl
local function load_claude_prompts()
  local projects_dir = vim.fn.expand('~/.claude/projects')
  if vim.fn.isdirectory(projects_dir) ~= 1 then
    vim.notify('Claude projects directory not found.', vim.log.levels.WARN)
    return
  end
  local files = vim.fn.glob(projects_dir .. '/**/*.jsonl', false, true)
  if #files == 0 then
    vim.notify('No Claude session files found.', vim.log.levels.WARN)
    return
  end
  table.sort(files, function(a, b) return a > b end)

  local entries = {}
  for _, path in ipairs(files) do
    if #entries >= 50 then break end
    local lines = vim.fn.readfile(path)
    for _, line in ipairs(lines) do
      if #entries >= 50 then break end
      local ok, record = pcall(vim.fn.json_decode, line)
      if ok and record and record.type == 'user'
        and record.message and record.message.role == 'user'
        and record.message.content then
        local text = extract_text(record.message.content)
        if text and text ~= '' then
          entries[#entries + 1] = {
            timestamp = parse_iso_timestamp(record.timestamp),
            preview = text:sub(1, 80):gsub('\n', ' '),
            text = text,
          }
        end
      end
    end
  end

  if #entries == 0 then
    vim.notify('No Claude user prompts found.', vim.log.levels.WARN)
    return
  end
  open_history_picker('Claude Prompts', entries)
end

-- Select an agent response to insert: first pick agent, then browse history
function M.select_response()
  vim.ui.select({ 'Claude', 'Pi' }, { prompt = 'Select agent history:' }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if choice == 'Claude' then
        load_claude_history()
      else
        load_pi_history()
      end
    end)
  end)
end

-- Select a user prompt to insert: first pick agent, then browse prompt history
function M.select_prompt()
  vim.ui.select({ 'Claude', 'Pi' }, { prompt = 'Select agent prompts:' }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if choice == 'Claude' then
        load_claude_prompts()
      else
        load_pi_prompts()
      end
    end)
  end)
end

return M
