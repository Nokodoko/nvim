-- Terraform Resource Documentation Lookup
-- Uses vim.net.request() to fetch docs from HashiCorp registry

local M = {}

--- Extract resource type under cursor (e.g., "aws_instance")
---@return string|nil resource_type
local function get_resource_under_cursor()
  local word = vim.fn.expand('<cWORD>')
  -- Match terraform resource patterns like aws_instance, google_compute_instance, etc.
  local resource = word:match('["\']?([a-z]+_[a-z0-9_]+)["\']?')
  if resource then
    return resource
  end
  -- Fallback to simpler word match
  word = vim.fn.expand('<cword>')
  if word:match('^[a-z]+_[a-z0-9_]+$') then
    return word
  end
  return nil
end

--- Parse provider and resource slug from resource type
---@param resource_type string e.g., "aws_instance"
---@return string|nil provider
---@return string|nil slug
local function parse_resource(resource_type)
  local provider, slug = resource_type:match('^([a-z]+)_(.+)$')
  return provider, slug
end

--- Create a floating window with markdown content
---@param content string markdown content
---@param title string window title
local function show_floating_window(content, title)
  local buf = vim.api.nvim_create_buf(false, true)

  local lines = vim.split(content, '\n')
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].modifiable = false

  -- Max 80 cols x 20 rows, auto-shrink to content
  local content_width = 0
  for _, line in ipairs(lines) do
    content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
  end
  local width = math.min(80, math.max(40, content_width + 2))
  local height = math.min(20, #lines)

  -- Smart placement: below cursor if space, above if not
  local cursor_row = vim.fn.screenrow()
  local screen_height = vim.o.lines
  local row = 1
  if cursor_row + height + 3 > screen_height then
    row = -height - 1
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'cursor',
    row = row,
    col = 0,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })

  -- Close on q or Escape
  vim.keymap.set('n', 'q', '<Cmd>close<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', '<Cmd>close<CR>', { buffer = buf, silent = true })

  -- Scroll navigation: j/k for line, <C-d>/<C-u> for page
  vim.keymap.set('n', 'j', '<C-e>', { buffer = buf, silent = true })
  vim.keymap.set('n', 'k', '<C-y>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<C-d>', '<C-d>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<C-u>', '<C-u>', { buffer = buf, silent = true })

  -- Close on cursor movement (CursorMoved event)
  local augroup = vim.api.nvim_create_augroup('TerraformDocsPopup', { clear = true })
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = augroup,
    buffer = buf,
    once = true,
    callback = function()
      -- Don't close if we're just scrolling
    end,
  })
  -- Close when leaving the window
  vim.api.nvim_create_autocmd('WinLeave', {
    group = augroup,
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.api.nvim_win_close, win, true)
    end,
  })

  -- Enable treesitter highlighting if available
  pcall(vim.treesitter.start, buf, 'markdown')

  return buf, win
end

--- Extract relevant sections from raw markdown docs
---@param raw_content string raw markdown from GitHub
---@return string formatted content
local function extract_doc_sections(raw_content)
  local lines = {}
  local in_section = false
  local section_depth = 0

  for line in raw_content:gmatch('[^\n]*') do
    -- Check for section headers we care about
    local header_level, header_text = line:match('^(#+)%s+(.+)$')
    if header_level then
      local level = #header_level
      local lower_text = header_text:lower()

      if lower_text:match('argument') or lower_text:match('attribute')
         or lower_text:match('example') or lower_text:match('import') then
        in_section = true
        section_depth = level
        table.insert(lines, line)
      elseif in_section and level <= section_depth then
        -- New top-level section, check if we should continue
        if lower_text:match('argument') or lower_text:match('attribute')
           or lower_text:match('example') or lower_text:match('import') then
          table.insert(lines, '')
          table.insert(lines, line)
        else
          in_section = false
        end
      elseif in_section then
        table.insert(lines, line)
      end
    elseif in_section then
      table.insert(lines, line)
    end
  end

  if #lines == 0 then
    -- Return first 100 lines if no sections found
    local count = 0
    for line in raw_content:gmatch('[^\n]*') do
      table.insert(lines, line)
      count = count + 1
      if count >= 100 then break end
    end
  end

  return table.concat(lines, '\n')
end

--- Open browser to registry page as fallback
---@param provider string
---@param slug string
local function open_browser_fallback(provider, slug)
  local url = string.format(
    'https://registry.terraform.io/providers/hashicorp/%s/latest/docs/resources/%s',
    provider, slug
  )
  local cmd
  if vim.fn.has('mac') == 1 then
    cmd = { 'open', url }
  elseif vim.fn.has('wsl') == 1 then
    cmd = { 'wslview', url }
  else
    cmd = { 'xdg-open', url }
  end
  vim.fn.jobstart(cmd, { detach = true })
  vim.notify('Opening docs in browser: ' .. url, vim.log.levels.INFO)
end

--- Fetch and display documentation for resource under cursor
function M.lookup()
  local resource_type = get_resource_under_cursor()
  if not resource_type then
    vim.notify('No Terraform resource found under cursor', vim.log.levels.WARN)
    return
  end

  local provider, slug = parse_resource(resource_type)
  if not provider or not slug then
    vim.notify('Could not parse resource: ' .. resource_type, vim.log.levels.WARN)
    return
  end

  vim.notify(string.format('Fetching docs for %s_%s...', provider, slug), vim.log.levels.INFO)

  -- Try fetching raw docs from GitHub
  local doc_url = string.format(
    'https://raw.githubusercontent.com/hashicorp/terraform-provider-%s/main/website/docs/r/%s.html.markdown',
    provider, slug
  )

  vim.net.request({
    url = doc_url,
    method = 'GET',
  }, function(err, response)
    vim.schedule(function()
      if err then
        -- Try alternate path structure
        local alt_url = string.format(
          'https://raw.githubusercontent.com/hashicorp/terraform-provider-%s/main/website/docs/resources/%s.md',
          provider, slug
        )

        vim.net.request({
          url = alt_url,
          method = 'GET',
        }, function(err2, response2)
          vim.schedule(function()
            if err2 or not response2 or response2.status ~= 200 then
              open_browser_fallback(provider, slug)
              return
            end

            local content = extract_doc_sections(response2.body)
            local title = string.format('%s_%s', provider, slug)
            show_floating_window(content, title)
          end)
        end)
        return
      end

      if not response then
        vim.notify('No response received', vim.log.levels.WARN)
        open_browser_fallback(provider, slug)
        return
      end

      if response.status ~= 200 then
        -- Try alternate path for newer provider doc structure
        local alt_url = string.format(
          'https://raw.githubusercontent.com/hashicorp/terraform-provider-%s/main/website/docs/resources/%s.md',
          provider, slug
        )

        vim.net.request({
          url = alt_url,
          method = 'GET',
        }, function(err2, response2)
          vim.schedule(function()
            if err2 or not response2 or response2.status ~= 200 then
              open_browser_fallback(provider, slug)
              return
            end

            local content = extract_doc_sections(response2.body)
            local title = string.format('%s_%s', provider, slug)
            show_floating_window(content, title)
          end)
        end)
        return
      end

      local content = extract_doc_sections(response.body)
      local title = string.format('%s_%s', provider, slug)
      show_floating_window(content, title)
    end)
  end)
end

return M
