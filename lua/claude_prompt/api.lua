-- Claude API communication module using claude CLI
local M = {}

-- Default configuration
M.config = {
  model = 'icarus',
  max_tokens = 1024,
}

-- Available models.
--   backend = 'claude'  -> shells out to `claude -p --model <id>`
--   backend = 'openai'  -> POSTs to an OpenAI-compatible /v1/chat/completions
--                          (local inference; `host` + `model` are the target)
-- 'icarus' is the default: the DeepSeek-V4.1 vLLM server on monty, the same
-- endpoint the :Icarus chat uses (see plugin/40_plugins.lua, nvim-model:managed).
M.models = {
  { name = 'icarus', id = 'icarus', backend = 'openai',
    host = 'http://monty:8010', model = 'deepseek-v4.1-flash' },
  { name = 'Sonnet 4.5', id = 'sonnet', backend = 'claude' },
  { name = 'Opus 4.6', id = 'opus', backend = 'claude' },
  { name = 'Haiku 4.5', id = 'haiku', backend = 'claude' },
}

-- Bearer token for the vLLM-served DeepSeek endpoint (monty:8010). Unlike
-- llama.cpp, vLLM ENFORCES auth, so a placeholder key is not enough.
-- $DSV41_API_KEY first (the same variable icarus reads -- api_key_env in
-- ~/.icarus/settings.json), then the serve.env it is defined in, parsed with
-- awk rather than a shell (vim.fn.system runs argv directly). Cached: this
-- sits on the path of every request and cannot change within a session.
local cached_api_key = nil

function M.api_key()
  if cached_api_key then return cached_api_key end

  local key = vim.env.DSV41_API_KEY
  if not key or key == '' then
    local out = vim.fn.system({
      'awk', '-F=', '/DSV41_API_KEY/{print$2}',
      vim.fn.expand('~/.config/icarus/serve.env'),
    })
    key = (out or ''):gsub('^%s+', ''):gsub('%s+$', '')
  end

  cached_api_key = key
  return key
end

-- Look up the model table entry for the active model
function M.current_model()
  for _, model in ipairs(M.models) do
    if model.id == M.config.model then return model end
  end
  return nil
end

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
  local model = M.current_model()
  return model and model.name or 'Unknown'
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
  local system_prompt = [[You are a coding assistant embedded in Neovim. Your output is inserted directly into the user's buffer.

Rules:
- Output ONLY what was requested — no explanations, no preamble, no commentary
- Do not wrap output in markdown code fences unless explicitly asked
- Match the existing code style exactly
- If asked for code, output only the code
- If asked a question, answer in the fewest words possible]]

  -- Build the user prompt with context
  local user_prompt = M.build_prompt(prompt, context)

  local model = M.current_model() or { name = M.config.model, id = M.config.model, backend = 'claude' }

  -- Per-backend command, stdin payload, and response parser. Both backends
  -- receive their payload on stdin so nothing is shell-escaped into argv.
  local cmd, stdin_payload, parse
  if model.backend == 'openai' then
    cmd = {
      'curl', '-sS', '--max-time', '180',
      '-H', 'Content-Type: application/json',
      '-H', 'Authorization: Bearer ' .. M.api_key(),
      '-d', '@-',
      model.host .. '/v1/chat/completions',
    }
    stdin_payload = vim.json.encode({
      model = model.model,
      temperature = 0,
      max_tokens = 4096,
      -- DeepSeek-V4.1 emits reasoning by default; it burns the token budget
      -- and is useless for buffer insertion. Verified live on monty:8010:
      -- `thinking=false` suppresses it (0 reasoning tokens); the llama.cpp
      -- spelling `enable_thinking=false` does NOT on this vLLM endpoint.
      chat_template_kwargs = { thinking = false },
      messages = {
        { role = 'system', content = system_prompt },
        { role = 'user', content = user_prompt },
      },
    })
    parse = function(raw)
      local ok, res = pcall(vim.json.decode, raw)
      if not ok or type(res) ~= 'table' then
        return nil, 'unparseable response from ' .. model.name .. ': ' .. raw:sub(1, 200)
      end
      if res.error then
        local msg = type(res.error) == 'table' and res.error.message or tostring(res.error)
        return nil, model.name .. ' error: ' .. tostring(msg)
      end
      local choice = res.choices and res.choices[1]
      local content = choice and choice.message and choice.message.content
      if type(content) ~= 'string' or content == '' then
        local why = choice and choice.finish_reason == 'length' and ' (hit max_tokens)' or ''
        return nil, 'Empty response from ' .. model.name .. why
      end
      return (content:gsub('^%s+', ''):gsub('%s+$', ''))
    end
  else
    -- claude CLI (prompt piped via stdin)
    cmd = {
      'claude',
      '-p',
      '--model', model.id,
      '--no-session-persistence',
      '--permission-mode', 'acceptEdits',
      '--system-prompt', system_prompt,
    }
    stdin_payload = user_prompt
    parse = function(raw)
      if raw == '' then return nil, 'Empty response from claude CLI' end
      return raw
    end
  end

  -- Collect response chunks
  local stdout_chunks = {}
  local stderr_chunks = {}

  -- Start job and write prompt to stdin
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
          local error_msg = cmd[1] .. ' failed (exit ' .. exit_code .. ')'
          if #stderr_chunks > 0 then
            error_msg = error_msg .. ': ' .. table.concat(stderr_chunks, '\n')
          end
          callback(nil, error_msg)
          return
        end

        local response_text, err = parse(table.concat(stdout_chunks, '\n'))
        callback(response_text, err)
      end)
    end,
  })

  -- Handle jobstart failure
  if job_id == 0 then
    callback(nil, 'Invalid job arguments')
    return
  elseif job_id == -1 then
    callback(nil, cmd[1] .. ' command not found or not executable')
    return
  end

  current_job_id = job_id

  -- Send payload via stdin then close to signal EOF
  vim.fn.chansend(job_id, stdin_payload)
  vim.fn.chanclose(job_id, 'stdin')
end

return M
