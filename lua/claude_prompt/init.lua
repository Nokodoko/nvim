-- Claude prompt module - main entry point
local M = {}

local api = require('claude_prompt.api')
local context = require('claude_prompt.context')

-- Setup function to configure the API module
function M.setup(opts)
  api.setup(opts)
end

-- Internal helper to create completion items from Claude response
local function show_completion(response_text)
  -- Split response into lines for display but keep as single completion item
  local lines = vim.split(response_text, '\n', { plain = true })

  -- Create completion item
  local items = {
    {
      word = response_text,
      abbr = lines[1]:sub(1, 80), -- First line truncated for menu
      info = response_text, -- Full text in preview
      menu = '[Claude]',
    }
  }

  -- Trigger completion at current cursor column
  local col = vim.fn.col('.')
  vim.fn.complete(col, items)
end

-- Main prompt function - prompts Claude with current buffer context
function M.prompt()
  -- Check if API key is available
  if not vim.env.ANTHROPIC_API_KEY or vim.env.ANTHROPIC_API_KEY == '' then
    vim.notify('ANTHROPIC_API_KEY environment variable not set', vim.log.levels.ERROR)
    return
  end

  -- Check if already busy
  if api.is_busy() then
    vim.notify('Claude is already processing a request', vim.log.levels.WARN)
    return
  end

  -- Get user input
  vim.ui.input({ prompt = 'Claude: ' }, function(input)
    if not input or input == '' then
      return
    end

    -- Gather context from current buffer
    local ctx = context.gather({
      include_file = true,
      include_cursor = true,
      include_treesitter = true,
      include_symbols = false,
      include_selection = false,
    })

    -- Show thinking status
    vim.notify('Claude: Thinking...', vim.log.levels.INFO)

    -- Send request to API
    api.request(input, ctx, function(response_text, err)
      if err then
        vim.notify('Claude: ' .. err, vim.log.levels.ERROR)
        return
      end

      if response_text and response_text ~= '' then
        -- Show completion in pmenu
        vim.schedule(function()
          show_completion(response_text)
        end)
      else
        vim.notify('Claude: Empty response', vim.log.levels.WARN)
      end
    end)
  end)
end

-- Prompt with visual selection context
function M.prompt_visual()
  -- Check if API key is available
  if not vim.env.ANTHROPIC_API_KEY or vim.env.ANTHROPIC_API_KEY == '' then
    vim.notify('ANTHROPIC_API_KEY environment variable not set', vim.log.levels.ERROR)
    return
  end

  -- Check if already busy
  if api.is_busy() then
    vim.notify('Claude is already processing a request', vim.log.levels.WARN)
    return
  end

  -- Get user input
  vim.ui.input({ prompt = 'Claude (with selection): ' }, function(input)
    if not input or input == '' then
      return
    end

    -- Gather context including visual selection
    local ctx = context.gather({
      include_file = true,
      include_cursor = true,
      include_treesitter = true,
      include_symbols = false,
      include_selection = true,
    })

    -- Show thinking status
    vim.notify('Claude: Thinking...', vim.log.levels.INFO)

    -- Send request to API
    api.request(input, ctx, function(response_text, err)
      if err then
        vim.notify('Claude: ' .. err, vim.log.levels.ERROR)
        return
      end

      if response_text and response_text ~= '' then
        -- Show completion in pmenu
        vim.schedule(function()
          show_completion(response_text)
        end)
      else
        vim.notify('Claude: Empty response', vim.log.levels.WARN)
      end
    end)
  end)
end

-- Cancel in-flight request
M.cancel = api.cancel

return M
