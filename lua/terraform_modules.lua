-- Terraform Module Search
-- Uses vim.net.request() to search HashiCorp registry and mini.pick to display results

local M = {}

--- Format module info for preview
---@param module table module data from API
---@return string[] lines for preview
local function format_module_preview(module)
  local lines = {}

  table.insert(lines, '# ' .. module.namespace .. '/' .. module.name)
  table.insert(lines, '')
  table.insert(lines, '**Provider:** ' .. (module.provider or 'unknown'))
  table.insert(lines, '**Version:** ' .. (module.version or 'latest'))
  table.insert(lines, '')

  if module.verified then
    table.insert(lines, '**Verified Module**')
    table.insert(lines, '')
  end

  if module.downloads then
    local downloads = module.downloads
    if downloads >= 1000000 then
      downloads = string.format('%.1fM', downloads / 1000000)
    elseif downloads >= 1000 then
      downloads = string.format('%.1fK', downloads / 1000)
    end
    table.insert(lines, '**Downloads:** ' .. downloads)
    table.insert(lines, '')
  end

  if module.description and module.description ~= '' then
    table.insert(lines, '## Description')
    table.insert(lines, '')
    table.insert(lines, module.description)
    table.insert(lines, '')
  end

  table.insert(lines, '## Usage')
  table.insert(lines, '')
  table.insert(lines, '```hcl')
  table.insert(lines, 'module "' .. module.name .. '" {')
  table.insert(lines, '  source  = "' .. module.namespace .. '/' .. module.name .. '/' .. (module.provider or 'aws') .. '"')
  table.insert(lines, '  version = "' .. (module.version or 'latest') .. '"')
  table.insert(lines, '')
  table.insert(lines, '  # Required inputs')
  table.insert(lines, '  # ...')
  table.insert(lines, '}')
  table.insert(lines, '```')

  return lines
end

--- Generate module block for insertion
---@param module table module data from API
---@return string[] lines to insert
local function generate_module_block(module)
  local lines = {}
  table.insert(lines, 'module "' .. module.name .. '" {')
  table.insert(lines, '  source  = "' .. module.namespace .. '/' .. module.name .. '/' .. (module.provider or 'aws') .. '"')
  table.insert(lines, '  version = "' .. (module.version or 'latest') .. '"')
  table.insert(lines, '')
  table.insert(lines, '  # TODO: Add required inputs')
  table.insert(lines, '}')
  return lines
end

--- Insert module block at cursor position
---@param module table module data from API
local function insert_module(module)
  local lines = generate_module_block(module)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
  vim.notify('Inserted module: ' .. module.namespace .. '/' .. module.name, vim.log.levels.INFO)
end

--- Search terraform registry for modules
---@param query string search query
---@param callback function(modules) callback with results
local function search_registry(query, callback)
  local url = string.format(
    'https://registry.terraform.io/v1/modules/search?q=%s&limit=20',
    vim.uri_encode(query)
  )

  vim.net.request({
    url = url,
    method = 'GET',
  }, function(err, response)
    vim.schedule(function()
      if err then
        vim.notify('Failed to search registry: ' .. tostring(err), vim.log.levels.ERROR)
        callback({})
        return
      end

      if not response or response.status ~= 200 then
        vim.notify('Registry search failed: HTTP ' .. (response and response.status or 'unknown'), vim.log.levels.ERROR)
        callback({})
        return
      end

      local ok, data = pcall(vim.json.decode, response.body)
      if not ok or not data or not data.modules then
        vim.notify('Failed to parse registry response', vim.log.levels.ERROR)
        callback({})
        return
      end

      callback(data.modules)
    end)
  end)
end

--- Open mini.pick with module search results
---@param modules table[] array of module data
local function show_picker(modules)
  if #modules == 0 then
    vim.notify('No modules found', vim.log.levels.WARN)
    return
  end

  local ok, pick = pcall(require, 'mini.pick')
  if not ok then
    vim.notify('mini.pick not available', vim.log.levels.ERROR)
    return
  end

  -- Store modules indexed by display text for lookup
  local module_lookup = {}

  -- Build items for picker (strings for compatibility)
  local items = {}
  for _, module in ipairs(modules) do
    local verified_mark = module.verified and ' [verified]' or ''
    local text = string.format(
      '%s/%s (%s) v%s%s',
      module.namespace,
      module.name,
      module.provider or 'unknown',
      module.version or 'latest',
      verified_mark
    )
    table.insert(items, text)
    module_lookup[text] = module
  end

  pick.start({
    source = {
      name = 'Terraform Modules',
      items = items,
      preview = function(buf_id, item)
        if not item then return end
        local module = module_lookup[item]
        if not module then return end
        local lines = format_module_preview(module)
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
        vim.bo[buf_id].filetype = 'markdown'
        pcall(vim.treesitter.start, buf_id, 'markdown')
      end,
      choose = function(item)
        if not item then return end
        local module = module_lookup[item]
        if not module then return end
        insert_module(module)
      end,
    },
  })
end

--- Prompt for search query and search registry
function M.search()
  vim.ui.input({ prompt = 'Search Terraform modules: ' }, function(query)
    if not query or query == '' then
      return
    end

    vim.notify('Searching for modules: ' .. query, vim.log.levels.INFO)

    search_registry(query, function(modules)
      show_picker(modules)
    end)
  end)
end

return M
