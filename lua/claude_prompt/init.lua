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

-- Internal helper: modal prompt field at the cursor (see claude_prompt.ui)
local function open_prompt(include_selection)
  if api.is_busy() then
    vim.notify(api.get_model_name() .. ' is already processing a request', vim.log.levels.WARN)
    return
  end

  -- Save original buffer and cursor before prompt opens
  local target_buf = vim.api.nvim_get_current_buf()
  local target_line = vim.api.nvim_win_get_cursor(0)[1]

  require('claude_prompt.ui').open({ model_name = api.get_model_name(), on_submit = function(input)
    local ctx = context.gather({
      include_file = true,
      include_cursor = true,
      include_treesitter = true,
      include_symbols = false,
      include_selection = include_selection,
    })

    local who = api.get_model_name()
    vim.notify(who .. ': Thinking...', vim.log.levels.INFO)

    api.request(input, ctx, function(response_text, err)
      if err then
        vim.notify(who .. ': ' .. err, vim.log.levels.ERROR)
        return
      end

      if response_text and response_text ~= '' then
        insert_response(target_buf, target_line, response_text)
      else
        vim.notify(who .. ' returned an empty response', vim.log.levels.ERROR)
      end
    end)
  end })
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

-- How many history entries a picker holds. The pickers exist to find a
-- RECENT return, so this bounds the newest N across all sessions; it is not
-- a per-file cap (see collect_newest).
M.HISTORY_LIMIT = 300

--- The newest `limit` entries across session files.
---
--- `files` are newest-session-first; each file's records are chronological.
--- The old scans took the FIRST `limit` matches they met -- the OLDEST replies
--- of the newest session -- and stopped, so in any long session the most
--- recent returns (the ones a user reaches for) were exactly the ones missing
--- from the picker. This takes each file's TAIL instead, walks back through
--- sessions until `limit` is reached, and orders the result newest-first.
---@param files string[] newest first
---@param limit integer
---@param read fun(path: string): table[] chronological entries of one file
---@return table[]
local function collect_newest(files, limit, read)
  local entries = {}
  for _, path in ipairs(files) do
    if #entries >= limit then break end
    local found = read(path)
    for i = #found, math.max(1, #found - (limit - #entries) + 1), -1 do
      entries[#entries + 1] = found[i]
    end
  end
  table.sort(entries, function(a, b) return (a.timestamp or 0) > (b.timestamp or 0) end)
  return entries
end

-- Scan JSONL session files and collect messages matching a role
-- For 'assistant' role, also captures custom_message records (e.g. intent-gate output)
local function collect_jsonl_entries(files, role, limit)
  return collect_newest(files, limit, function(path)
    local entries = {}
    for _, line in ipairs(vim.fn.readfile(path)) do
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
          session = vim.fn.fnamemodify(path, ':t:r'):sub(-8),
        }
      end

      ::continue::
    end
    return entries
  end)
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

-- Icarus sessions: ~/.icarus/sessions/<project>/<id>.jsonl, flat records of
-- type user_message / assistant_message with `text` and `ts`. The per-project
-- `usage/` subfolder holds token accounting, not conversation, and is skipped.
-- Overridable so tests can point at a synthetic sessions tree.
M.icarus_sessions_dir = '~/.icarus/sessions'

local function get_icarus_session_files()
  local sessions_dir = vim.fn.expand(M.icarus_sessions_dir)
  if vim.fn.isdirectory(sessions_dir) ~= 1 then
    vim.notify('Icarus sessions directory not found: ' .. sessions_dir, vim.log.levels.WARN)
    return nil
  end
  local files = vim.tbl_filter(
    function(path) return not path:find('/usage/', 1, true) end,
    vim.fn.glob(sessions_dir .. '/**/*.jsonl', false, true)
  )
  if #files == 0 then
    vim.notify('No Icarus session files found.', vim.log.levels.WARN)
    return nil
  end
  -- mtime order, same rationale as get_pi_session_files
  local mtimes = {}
  for _, path in ipairs(files) do
    local stat = vim.loop.fs_stat(path)
    mtimes[path] = (stat and stat.mtime and stat.mtime.sec) or 0
  end
  table.sort(files, function(a, b) return mtimes[a] > mtimes[b] end)
  return files
end

-- Collect icarus records of one type ('user_message' | 'assistant_message').
-- Returns the newest `limit` entries across `files` (see collect_newest).
-- Lines are pre-filtered by a plain substring match before json_decode:
-- session files run to ~1 MB and the decode dominated the old scan.
local function collect_icarus_entries(files, record_type, limit)
  local needle = '"type":"' .. record_type .. '"'
  return collect_newest(files, limit, function(path)
    local found = {}
    for _, line in ipairs(vim.fn.readfile(path)) do
      if line:find(needle, 1, true) then
        local ok, record = pcall(vim.fn.json_decode, line)
        if ok and record and record.type == record_type
          and type(record.text) == 'string' and record.text ~= '' then
          local text = strip_ansi(record.text)
          found[#found + 1] = {
            timestamp = parse_iso_timestamp(record.ts),
            preview = text:sub(1, 80):gsub('\n', ' '),
            text = text,
            session = vim.fn.fnamemodify(path, ':t:r'):sub(-8),
          }
        end
      end
    end
    return found
  end)
end

-- Insert last Icarus response: final assistant_message of the newest session
-- that has one. A freshly opened session holds only session_start, so the
-- newest file is often empty; walk back until a reply is found.
local function insert_last_icarus_response()
  local files = get_icarus_session_files()
  if not files then return end
  for _, path in ipairs(files) do
    local entries = collect_icarus_entries({ path }, 'assistant_message', 9999)
    if #entries > 0 then
      local last = entries[#entries]
      insert_lines_at_cursor(vim.split(last.text, '\n', { plain = true }), 'Icarus response')
      return
    end
  end
  vim.notify('No Icarus assistant responses found.', vim.log.levels.WARN)
end

-- Agents offered by the three history pickers, in menu order
local AGENTS = { 'Icarus', 'Claude', 'Pi' }

-- Insert last response: pick agent first
function M.insert_last_response()
  vim.ui.select(AGENTS, { prompt = 'Insert last response from:' }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if choice == 'Icarus' then
        insert_last_icarus_response()
      elseif choice == 'Claude' then
        insert_last_claude_response()
      else
        insert_last_pi_response()
      end
    end)
  end)
end

local preview_ns = vim.api.nvim_create_namespace('claude_prompt_preview')

--- Score how well `line` matches `prompt` (both lower-cased): an exact
--- substring wins outright; otherwise the fuzzy score is the count of prompt
--- characters found in order (the same notion telescope's sorter uses).
local function line_score(line, prompt)
  if line:find(prompt, 1, true) then return math.huge end
  local pos, n = 1, 0
  for i = 1, #prompt do
    local c = prompt:sub(i, i)
    if c ~= ' ' then
      local at = line:find(c, pos, true)
      if not at then break end
      n, pos = n + 1, at + 1
    end
  end
  return n
end

--- 1-based row of the line in `lines` that best matches `prompt`, or nil
--- when the prompt is empty or nothing matches at all.
function M.find_best_line(lines, prompt)
  prompt = vim.trim((prompt or ''):lower())
  if prompt == '' then return nil end
  local best_row, best = nil, 0
  for i, line in ipairs(lines) do
    local s = line_score(line:lower(), prompt)
    if s > best then best_row, best = i, s end
    if s == math.huge then break end
  end
  return best_row
end
local find_best_line = M.find_best_line

--- Highlight every occurrence of each whitespace-separated prompt token.
local function highlight_query(bufnr, lines, prompt)
  vim.api.nvim_buf_clear_namespace(bufnr, preview_ns, 0, -1)
  for token in (prompt or ''):lower():gmatch('%S+') do
    for i, line in ipairs(lines) do
      local lower, from = line:lower(), 1
      while true do
        local s, e = lower:find(token, from, true)
        if not s then break end
        vim.api.nvim_buf_set_extmark(bufnr, preview_ns, i - 1, s - 1, { end_col = e, hl_group = 'Search' })
        from = e + 1
      end
    end
  end
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
          local display = string.format('[%s%s] %s', age,
            entry.session and (' ' .. entry.session) or '', entry.preview or '(empty)')
          return {
            value = entry,
            display = display,
            -- Fuzzy-match against the WHOLE return, not the 80-char preview:
            -- a phrase remembered from the middle of a reply must find it.
            -- Newlines collapsed so a query can span a line break; capped so
            -- the sorter stays responsive on very long returns.
            ordinal = (entry.text or ''):sub(1, 20000):gsub('%s+', ' '),
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
          -- Open the preview AT the match, not at the top: the ordinal is the
          -- whole return, so the line that satisfied the query is often far
          -- below the fold and the entry looks like a miss. Pick the line that
          -- best matches the prompt (exact substring first, then the most
          -- query characters in order), scroll it to the top of the preview,
          -- and highlight the query tokens on every line.
          local prompt = action_state.get_current_line()
          local row = find_best_line(lines, prompt)
          if row then
            vim.schedule(function()
              if not (vim.api.nvim_win_is_valid(self.state.winid) and vim.api.nvim_buf_is_valid(self.state.bufnr)) then return end
              vim.api.nvim_win_set_cursor(self.state.winid, { row, 0 })
              vim.api.nvim_win_call(self.state.winid, function() vim.cmd('normal! zt') end)
              highlight_query(self.state.bufnr, lines, prompt)
            end)
          end
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
  local entries = collect_jsonl_entries(files, 'assistant', M.HISTORY_LIMIT)
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
  local entries = collect_jsonl_entries(files, 'user', M.HISTORY_LIMIT)
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

-- Load Icarus agent responses from ~/.icarus/sessions/**/*.jsonl
local function load_icarus_history()
  local files = get_icarus_session_files()
  if not files then return end
  local entries = collect_icarus_entries(files, 'assistant_message', M.HISTORY_LIMIT)
  if #entries == 0 then
    vim.notify('No Icarus assistant responses found.', vim.log.levels.WARN)
    return
  end
  open_history_picker('Icarus Responses', entries)
end

-- Load Icarus user prompts from ~/.icarus/sessions/**/*.jsonl
local function load_icarus_prompts()
  local files = get_icarus_session_files()
  if not files then return end
  local entries = collect_icarus_entries(files, 'user_message', M.HISTORY_LIMIT)
  if #entries == 0 then
    vim.notify('No Icarus user prompts found.', vim.log.levels.WARN)
    return
  end
  open_history_picker('Icarus Prompts', entries)
end

-- Exposed for tests (tests/test_history_picker.lua).
M._collect_icarus_entries = collect_icarus_entries
M._get_icarus_session_files = get_icarus_session_files

-- Select an agent response to insert: first pick agent, then browse history
function M.select_response()
  vim.ui.select(AGENTS, { prompt = 'Select agent history:' }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if choice == 'Icarus' then
        load_icarus_history()
      elseif choice == 'Claude' then
        load_claude_history()
      else
        load_pi_history()
      end
    end)
  end)
end

-- Select a user prompt to insert: first pick agent, then browse prompt history
function M.select_prompt()
  vim.ui.select(AGENTS, { prompt = 'Select agent prompts:' }, function(choice)
    if not choice then return end
    vim.schedule(function()
      if choice == 'Icarus' then
        load_icarus_prompts()
      elseif choice == 'Claude' then
        load_claude_prompts()
      else
        load_pi_prompts()
      end
    end)
  end)
end

return M
