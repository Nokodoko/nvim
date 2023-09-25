--vim.fn.systemlist('ls'))
----.*vim.fn.systemlist('echo hello' .. vim.fn.expand("%:p:h")))
----.* vim.split(vim.system('echo hello'), '\n', 1) )



--local api = vim.api
---- Use fd to find files in the current directory
--local function find_files()
--  local fd = vim.fn.systemlist('fd . ' .. vim.fn.expand("%:p:h"))
--  if vim.v.shell_error ~= 0 then
--    print("fd command failed")
--    return
--  end
--  -- Create a new buffer
--  local buf = api.nvim_create_buf(false, true)
--  -- Add the file list to the buffer
--  api.nvim_buf_set_lines(buf, 0, -1, false, fd)
--  -- Create a new window with the buffer
--  local win = api.nvim_open_win(buf, true, {
--    relative = 'editor',
--    width = 40,
--    height = 20,
--    col = 20,
--    row = 10,
--  })
--  -- Set some options for the window
--  api.nvim_win_set_option(win, 'wrap', false)
--  api.nvim_win_set_option(win, 'cursorline', true)
--end
--find_files()

--local function test()
--    local t = {}
--
--    return t
--end

----.*vim.api)

--local telescope = require('telescope')
--local finders = require('telescope.finders')
--local pickers = require('telescope.pickers')
--local sorters = require('telescope.sorters')
--local previewers = require('telescope.previewers')
--telescope.setup{
--  defaults = {
--    file_sorter =  require'telescope.sorters'.get_fzy_sorter,
--    prompt_prefix = ' >',
--    color_devicons = true,
--    file_previewer   = require'telescope.previewers'.vim_buffer_cat.new,
--    grep_previewer   = require'telescope.previewers'.vim_buffer_vimgrep.new,
--    qflist_previewer = require'telescope.previewers'.vim_buffer_qflist.new,
--    mappings = {
--      i = {
--        ["<C-x>"] = false,
--        ["<C-q>"] = require'telescope.actions'.send_to_qflist,
--      },
--    },
--  },
--  pickers = {
--    find_files = {
--      theme = "dropdown",
--      previewer = false
--    }
--  },
--  extensions = {
--    fzy_native = {
--      override_generic_sorter = false,
--      override_file_sorter = true,
--    }
--  }
--}
--telescope.load_extension('fzy_native')
--
---- Use fd to find files in the current directory
--local function find_files()
--  local fd = vim.fn.systemlist('fd . ' .. vim.fn.expand("%:p:h"))
--  if vim.v.shell_error ~= 0 then
--    print("fd command failed")
--    return
--  end
--  pickers.new({}, {
--    prompt_title = 'Find Files',
--    finder = finders.new_table {
--      results = fd,
--      entry_maker = function(line)
--        return {
--          value = line,
--          ordinal = line,
--          display = line,
--          filename = line,
--        }
--      end,
--    },
--    sorter = sorters.get_fzy_sorter(),
--    previewer = previewers.vim_buffer_cat.new({}),
--  }):find()
--end
--find_files()






