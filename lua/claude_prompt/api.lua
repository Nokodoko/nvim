-- Claude API communication module using claude CLI
local M = {}

-- Default configuration
M.config = {
  model = 'sonnet',
  max_tokens = 1024,
}

-- Available models (short aliases for claude CLI)
M.models = {
  { name = 'Sonnet 4.5', id = 'sonnet' },
  { name = 'Opus 4.6', id = 'opus' },
  { name = 'Haiku 4.5', id = 'haiku' },
}

-- Current job state
local current_job_id = nil

-- Setup function to override defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})
end

-- Set the current model
function M.set_model(model_id)
  M.config.model = model_id
end

-- Get the human-readable name for the current model
function M.get_model_name()
  for _, model in ipairs(M.models) do
    if model.id == M.config.model then
      return model.name
    end
  end
  return 'Unknown'
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

-- Build prompt string with context
function M.build_prompt(prompt, context)
  local parts = {}

  if context.filepath then
    table.insert(parts, string.format('File: %s', context.filepath))
  end

  if context.filetype then
    table.insert(parts, string.format('Filetype: %s', context.filetype))
  end

  if context.cursor_line then
    table.insert(parts, string.format('Cursor line: %d', context.cursor_line))
  end

  if context.selection then
    table.insert(parts, '\n--- Selected Code ---')
    table.insert(parts, context.selection)
    table.insert(parts, '--- End Selection ---\n')
  end

  if context.buffer_content then
    table.insert(parts, '\n--- Current Buffer ---')
    table.insert(parts, context.buffer_content)
    table.insert(parts, '--- End Buffer ---\n')
  end

  table.insert(parts, '\n' .. prompt)

  return table.concat(parts, '\n')
end

-- Main request function using claude CLI
function M.request(prompt, context, callback)
  context = context or {}

  -- Cancel any existing request
  if M.is_busy() then
    M.cancel()
  end

  -- Build the system prompt
  local system_prompt = [[You are a helpful AI coding assistant integrated into Neovim. You have access to the user's codebase context and should provide concise, accurate responses focused on their immediate task.

When providing code suggestions:
- Be concise and to the point
- Match the existing code style
- Consider the file type and context
- Provide working, tested solutions when possible]]

  -- Build the user prompt with context
  local user_prompt = M.build_prompt(prompt, context)

  -- Build claude command
  local cmd = {
    'claude',
    '-p',
    '--model', M.config.model,
    '--no-session-persistence',
    '--system-prompt', system_prompt,
    '--allowedTools', '',
    user_prompt,
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

        -- Handle errors
        if exit_code ~= 0 then
          local error_msg = 'claude CLI failed (exit ' .. exit_code .. ')'
          if #stderr_chunks > 0 then
            error_msg = error_msg .. ': ' .. table.concat(stderr_chunks, '\n')
          end
          callback(nil, error_msg)
          return
        end

        -- Join response text
        local response_text = table.concat(stdout_chunks, '\n')

        if response_text and response_text ~= '' then
          callback(response_text, nil)
        else
          callback(nil, 'Empty response from claude CLI')
        end
      end)
    end,
  })

  -- Handle jobstart failure
  if job_id == 0 then
    callback(nil, 'Invalid job arguments')
    return
  elseif job_id == -1 then
    callback(nil, 'claude command not found or not executable')
    return
  end

  current_job_id = job_id
end

return M
