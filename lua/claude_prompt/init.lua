-- Claude prompt module - main entry point
local M = {}

local api = require('claude_prompt.api')
local context = require('claude_prompt.context')

-- Setup function to configure the API module
function M.setup(opts)
  api.setup(opts)
end

-- Internal helper to show Claude response in a floating window
local function show_response(response_text)
  local lines = vim.split(response_text, '\n', { plain = true })

  -- Create scratch buffer with response content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modifiable = false

  -- Calculate window size
  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)

  -- Open floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'cursor',
    width = width,
    height = height,
    row = 1,
    col = 0,
    style = 'minimal',
    border = 'rounded',
    title = ' Claude ',
    title_pos = 'center',
  })

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  -- Close with q or Esc
  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', '<Cmd>close<CR>', { buffer = buf, nowait = true })

  -- Yank response with y
  vim.keymap.set('n', 'y', function()
    vim.fn.setreg('+', response_text)
    vim.notify('Claude response copied to clipboard', vim.log.levels.INFO)
  end, { buffer = buf, nowait = true })
end

-- Internal helper to prompt Claude with or without selection
local function prompt_internal(include_selection)
  -- Pre-validation
  if not vim.env.ANTHROPIC_API_KEY or vim.env.ANTHROPIC_API_KEY == '' then
    vim.notify('ANTHROPIC_API_KEY environment variable not set', vim.log.levels.ERROR)
    return
  end

  if api.is_busy() then
    vim.notify('Claude is already processing a request', vim.log.levels.WARN)
    return
  end

  local prompt_text = include_selection and 'Claude (with selection): ' or 'Claude: '

  vim.ui.input({ prompt = prompt_text }, function(input)
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
        show_response(response_text)
      else
        vim.notify('Claude returned an empty response', vim.log.levels.ERROR)
      end
    end)
  end)
end

-- Main prompt function - prompts Claude with current buffer context
function M.prompt()
  prompt_internal(false)
end

-- Prompt with visual selection context
function M.prompt_visual()
  prompt_internal(true)
end

-- Cancel in-flight request
M.cancel = api.cancel

return M
