-- Claude API communication module
local M = {}

-- Default configuration
M.config = {
  model = 'claude-sonnet-4-5-20250929',
  max_tokens = 1024,
}

-- Current job state
local current_job_id = nil

-- Setup function to override defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

-- Check if a request is currently in flight
function M.is_busy()
  return current_job_id ~= nil
end

-- Cancel any in-flight request
function M.cancel()
  if current_job_id then
    vim.fn.jobstop(current_job_id)
    current_job_id = nil
  end
end

-- Build messages array for the API request
function M.build_messages(prompt, context)
  local system_prompt = [[You are a helpful AI coding assistant integrated into Neovim. You have access to the user's codebase context and should provide concise, accurate responses focused on their immediate task.

When providing code suggestions:
- Be concise and to the point
- Match the existing code style
- Consider the file type and context
- Provide working, tested solutions when possible]]

  -- Build user content with context
  local user_parts = {}

  if context.filepath then
    table.insert(user_parts, string.format('File: %s', context.filepath))
  end

  if context.filetype then
    table.insert(user_parts, string.format('Filetype: %s', context.filetype))
  end

  if context.cursor_line then
    table.insert(user_parts, string.format('Cursor line: %d', context.cursor_line))
  end

  if context.selection then
    table.insert(user_parts, '\n--- Selected Code ---')
    table.insert(user_parts, context.selection)
    table.insert(user_parts, '--- End Selection ---\n')
  end

  if context.buffer_content then
    table.insert(user_parts, '\n--- Current Buffer ---')
    table.insert(user_parts, context.buffer_content)
    table.insert(user_parts, '--- End Buffer ---\n')
  end

  table.insert(user_parts, '\n' .. prompt)

  return {
    system = system_prompt,
    messages = {
      { role = 'user', content = table.concat(user_parts, '\n') }
    }
  }
end

-- Main request function
function M.request(prompt, context, callback)
  context = context or {}

  -- Check for API key
  local api_key = vim.env.ANTHROPIC_API_KEY
  if not api_key or api_key == '' then
    callback(nil, 'ANTHROPIC_API_KEY environment variable not set')
    return
  end

  -- Cancel any existing request
  if M.is_busy() then
    M.cancel()
  end

  -- Build request body
  local msg_data = M.build_messages(prompt, context)
  local body = vim.json.encode({
    model = M.config.model,
    max_tokens = M.config.max_tokens,
    system = msg_data.system,
    messages = msg_data.messages,
  })

  -- Build curl command
  local cmd = {
    'curl', '-s',
    '--max-time', '30',
    '--connect-timeout', '10',
    '-X', 'POST',
    'https://api.anthropic.com/v1/messages',
    '-H', 'Content-Type: application/json',
    '-H', 'x-api-key: ' .. api_key,
    '-H', 'anthropic-version: 2023-06-01',
    '-d', body,
  }

  -- Collect response chunks
  local stdout_chunks = {}
  local stderr_chunks = {}

  -- Start job
  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,

    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(stdout_chunks, line)
          end
        end
      end
    end,

    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then
            table.insert(stderr_chunks, line)
          end
        end
      end
    end,

    on_exit = function(_, exit_code)
      vim.schedule(function()
        current_job_id = nil
        -- Handle curl errors
        if exit_code ~= 0 then
          local error_msg = 'curl request failed (exit ' .. exit_code .. ')'
          if #stderr_chunks > 0 then
            error_msg = error_msg .. ': ' .. table.concat(stderr_chunks, '\n')
          end
          callback(nil, error_msg)
          return
        end

        -- Parse JSON response
        local response_text = table.concat(stdout_chunks, '\n')
        local ok, response = pcall(vim.json.decode, response_text)

        if not ok then
          callback(nil, 'Failed to parse API response: ' .. tostring(response))
          return
        end

        -- Check for API errors
        if response.error then
          local error_msg = response.error.message or vim.json.encode(response.error)
          callback(nil, 'API error: ' .. error_msg)
          return
        end

        -- Extract text content from response
        if response.content and #response.content > 0 then
          local first_content = response.content[1]
          if first_content.type == 'text' and first_content.text then
            callback(first_content.text, nil)
          else
            callback(nil, 'Empty or non-text response from API')
          end
        else
          callback(nil, 'Unexpected API response format')
        end
      end)
    end,
  })

  -- Handle jobstart failure
  if job_id == 0 then
    callback(nil, 'Invalid job arguments')
    return
  elseif job_id == -1 then
    callback(nil, 'curl command not executable')
    return
  end

  current_job_id = job_id
end

return M
