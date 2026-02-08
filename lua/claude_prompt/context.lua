-- Context gathering module for Claude API prompts
local M = {}

-- Get context about the current buffer
-- @param bufnr number Buffer number
-- @return table { filepath, filetype, content, line_count }
function M.get_buffer_context(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return {} end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local filetype = vim.bo[bufnr].filetype
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local content = table.concat(lines, '\n')
  local line_count = #lines

  return {
    filepath = filepath,
    filetype = filetype,
    content = content,
    line_count = line_count,
  }
end

-- Get context around cursor position
-- @param bufnr number Buffer number
-- @param line number Line number (1-indexed)
-- @param col number Column number (0-indexed)
-- @param window number Lines before/after cursor (default 20)
-- @return table { text, cursor_line, start_line, end_line }
function M.get_cursor_context(bufnr, line, col, window)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  window = window or 20

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_line = math.max(0, line - 1 - window)
  local end_line = math.min(line_count, line + window)

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  local text = table.concat(lines, '\n')

  return {
    text = text,
    cursor_line = line,
    start_line = start_line + 1, -- Convert to 1-indexed
    end_line = end_line,
  }
end

-- Extract visually selected text
-- @return string|nil Selected text or nil if no selection
function M.get_visual_selection()
  -- Get the saved visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  -- Get lines from buffer
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  if #lines == 0 then return nil end

  -- Handle single line vs multi-line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
  end

  return table.concat(lines, '\n')
end

-- Get the treesitter node at cursor
-- @param bufnr number Buffer number
-- @param line number Line number (1-indexed)
-- @param col number Column number (0-indexed)
-- @return table|nil { type, name, text, start_line, end_line } or nil if not available
function M.get_treesitter_node(bufnr, line, col)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ok, result = pcall(function()
    -- Get node at cursor position (convert to 0-indexed)
    local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { line - 1, col } })
    if not node then return nil end

    -- Node types to look for when walking up the tree
    local function_types = {
      'function_definition',
      'function_declaration',
      'method_definition',
      'class_definition',
      'function',
      'local_function',
      'function_item', -- Rust
      'impl_item', -- Rust
      'arrow_function', -- JavaScript
      'method_declaration', -- Java
    }

    -- Walk up the tree to find enclosing function/class
    local parent = node
    while parent do
      local node_type = parent:type()
      for _, target_type in ipairs(function_types) do
        if node_type == target_type then
          local start_line, _, end_line, _ = parent:range()
          local text = vim.treesitter.get_node_text(parent, bufnr)

          -- Try to extract name from child nodes
          local name = nil
          for child in parent:iter_children() do
            local child_type = child:type()
            if child_type == 'identifier' or child_type == 'name' or child_type == 'field_identifier' then
              name = vim.treesitter.get_node_text(child, bufnr)
              break
            end
          end

          -- Determine semantic type
          local semantic_type = 'function'
          if node_type:match('class') then
            semantic_type = 'class'
          elseif node_type:match('method') then
            semantic_type = 'method'
          end

          return {
            type = semantic_type,
            name = name,
            text = text,
            start_line = start_line + 1, -- Convert to 1-indexed
            end_line = end_line + 1,
          }
        end
      end
      parent = parent:parent()
    end

    return nil
  end)

  if ok then
    return result
  else
    return nil
  end
end

-- Get document symbols from LSP
-- @param bufnr number Buffer number
-- @return table|nil List of { name, kind } or nil if not available
function M.get_lsp_symbols(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- Check if any LSP client is attached
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then return nil end

  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  local timeout_ms = 1000

  local ok, results = pcall(function()
    return vim.lsp.buf_request_sync(bufnr, 'textDocument/documentSymbol', params, timeout_ms)
  end)

  if not ok or not results then return nil end

  -- Process results from all clients
  local symbols = {}
  for _, result in pairs(results) do
    if result.result then
      -- Flatten nested symbols
      local function add_symbols(symbol_list)
        for _, symbol in ipairs(symbol_list) do
          table.insert(symbols, {
            name = symbol.name,
            kind = vim.lsp.protocol.SymbolKind[symbol.kind] or 'Unknown',
          })
          -- Recursively add children if present
          if symbol.children then
            add_symbols(symbol.children)
          end
        end
      end
      add_symbols(result.result)
    end
  end

  return #symbols > 0 and symbols or nil
end

-- Main function that combines all context
-- @param opts table Options { bufnr, include_file, include_cursor, include_treesitter, include_symbols, include_selection }
-- @return table Structured context data
function M.gather(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then return {} end

  local include_file = opts.include_file ~= false
  local include_cursor = opts.include_cursor ~= false
  local include_treesitter = opts.include_treesitter ~= false
  local include_symbols = opts.include_symbols or false
  local include_selection = opts.include_selection or false

  local context = {}

  -- Buffer context (flatten into top-level fields)
  if include_file then
    local buf = M.get_buffer_context(bufnr)
    context.filepath = buf.filepath
    context.filetype = buf.filetype
    context.buffer_content = buf.content
    context.line_count = buf.line_count
  end

  -- Cursor context
  if include_cursor then
    local cursor = vim.api.nvim_win_get_cursor(0)
    context.cursor_line = cursor[1]
    context.cursor_context = M.get_cursor_context(bufnr, cursor[1], cursor[2])
  end

  -- Visual selection - always attempt if requested (don't check mode, it's already exited)
  if include_selection then
    context.selection = M.get_visual_selection()
  end

  -- Treesitter node
  if include_treesitter then
    local cursor = vim.api.nvim_win_get_cursor(0)
    local node = M.get_treesitter_node(bufnr, cursor[1], cursor[2])
    if node then
      context.treesitter_node = node
    end
  end

  -- LSP symbols
  if include_symbols then
    context.symbols = M.get_lsp_symbols(bufnr)
  end

  return context
end

-- Format gathered context into a string suitable for Claude API prompt
-- @param context table Context returned by M.gather()
-- @return string Formatted context string
function M.format_for_prompt(context)
  local lines = {}

  -- File info
  if context.filepath then
    local filepath = context.filepath ~= '' and context.filepath or '[No Name]'
    table.insert(lines, string.format('File: %s (%s)', filepath, context.filetype or ''))
  end
  if context.line_count then
    table.insert(lines, string.format('Lines: %d', context.line_count))
  end

  -- Current function/class
  if context.treesitter_node then
    local ts = context.treesitter_node
    local name = ts.name or 'anonymous'
    table.insert(
      lines,
      string.format('Current %s: %s (lines %d-%d)', ts.type, name, ts.start_line, ts.end_line)
    )
  end

  -- Cursor position
  if context.cursor_line then
    table.insert(lines, string.format('Cursor at line: %d', context.cursor_line))
  end

  -- Visual selection
  if context.selection then
    table.insert(lines, '\n--- Selected Text ---')
    table.insert(lines, context.selection)
  end

  -- LSP symbols
  if context.symbols then
    table.insert(lines, '\n--- Document Symbols ---')
    for _, symbol in ipairs(context.symbols) do
      table.insert(lines, string.format('- %s (%s)', symbol.name, symbol.kind))
    end
  end

  -- Cursor context
  if context.cursor_context then
    table.insert(lines, '\n--- Context Around Cursor ---')
    table.insert(
      lines,
      string.format('(lines %d-%d)', context.cursor_context.start_line, context.cursor_context.end_line)
    )
    table.insert(lines, context.cursor_context.text)
  end

  -- Full file content
  if context.buffer_content then
    table.insert(lines, '\n--- File Content ---')
    table.insert(lines, context.buffer_content)
  end

  return table.concat(lines, '\n')
end

return M
