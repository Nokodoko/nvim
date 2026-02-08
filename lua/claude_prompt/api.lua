-- Claude API communication module
local M = {}

-- Default configuration
M.config = {
  model = 'claude-sonnet-4-5-20250929',
  max_tokens = 1024,
}

-- Available models
M.models = {
  { name = 'Sonnet 4.5', id = 'claude-sonnet-4-5-20250929' },
  { name = 'Opus 4.6', id = 'claude-opus-4-6' },
  { name = 'Haiku 4.5', id = 'claude-haiku-4-5-20251001' },
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

-- Read OAuth credentials from ~/.claude/.credentials.json
local function read_oauth_credentials()
  local cred_path = vim.fn.expand('~/.claude/.credentials.json')
  local file = io.open(cred_path, 'r')

  if not file then
    return nil, 'Credentials file not found at ' .. cred_path
  end

  local content = file:read('*all')
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok or not data or not data.claudeAiOauth then
    return nil, 'Failed to parse credentials file'
  end

  return data.claudeAiOauth, nil
end

-- Write updated OAuth credentials back to ~/.claude/.credentials.json
local function write_oauth_credentials(oauth_data)
  local cred_path = vim.fn.expand('~/.claude/.credentials.json')

  -- Read existing file to preserve structure
  local file = io.open(cred_path, 'r')
  if not file then
    return false, 'Could not open credentials file for writing'
  end

  local content = file:read('*all')
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return false, 'Failed to parse existing credentials'
  end

  -- Update OAuth section
  data.claudeAiOauth = oauth_data

  -- Write back
  file = io.open(cred_path, 'w')
  if not file then
    return false, 'Could not write to credentials file'
  end

  file:write(vim.json.encode(data))
  file:close()

  return true, nil
end

-- Refresh OAuth access token using refresh token (synchronous)
local function refresh_oauth_token(refresh_token)
  local body = vim.json.encode({
    grant_type = 'refresh_token',
    refresh_token = refresh_token,
    client_id = '9d1c250a-e61b-44d9-88ed-5944d1962f5e',
  })

  local curl_cmd = string.format(
    'curl -s -X POST https://console.anthropic.com/v1/oauth/token -H "Content-Type: application/json" -d %s',
    vim.fn.shellescape(body)
  )

  local response_text = vim.fn.system(curl_cmd)
  local ok, response = pcall(vim.json.decode, response_text)

  if not ok or not response or not response.access_token then
    return nil, 'Failed to refresh OAuth token'
  end

  return response, nil
end

-- Get authentication header and value (checks API key first, then OAuth)
local function get_auth_header()
  -- Priority 1: Direct API key from environment
  local api_key = vim.env.ANTHROPIC_API_KEY
  if api_key and api_key ~= '' then
    return 'x-api-key', api_key, nil
  end

  -- Priority 2: OAuth from ~/.claude/.credentials.json
  local oauth, err = read_oauth_credentials()
  if not oauth then
    return nil, nil, err
  end

  -- Check if token is expired (expiresAt is in milliseconds)
  local current_time_ms = os.time() * 1000
  if current_time_ms > oauth.expiresAt then
    -- Token expired, refresh it synchronously
    local refresh_response, refresh_err = refresh_oauth_token(oauth.refreshToken)
    if refresh_err then
      return nil, nil, 'OAuth token expired and refresh failed: ' .. refresh_err
    end

    -- Update credentials with new tokens
    oauth.accessToken = refresh_response.access_token
    oauth.refreshToken = refresh_response.refresh_token
    oauth.expiresAt = current_time_ms + (refresh_response.expires_in * 1000)

    local write_ok, write_err = write_oauth_credentials(oauth)
    if not write_ok then
      return nil, nil, 'Token refreshed but failed to save: ' .. (write_err or 'unknown error')
    end
  end

  return 'Authorization', 'Bearer ' .. oauth.accessToken, nil
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

  -- Get authentication credentials
  local auth_header, auth_value, auth_err = get_auth_header()
  if auth_err then
    callback(nil, auth_err)
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

  -- Build curl command with appropriate auth header
  local cmd = {
    'curl', '-s',
    '--max-time', '30',
    '--connect-timeout', '10',
    '-X', 'POST',
    'https://api.anthropic.com/v1/messages',
    '-H', 'Content-Type: application/json',
    '-H', auth_header .. ': ' .. auth_value,
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
