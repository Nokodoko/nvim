-- Terraform resource runner module
-- Run terraform plan/apply on resource at cursor in a zellij floating pane
local M = {}

-- Find the enclosing terraform resource block from cursor position
-- Returns { type = "aws_instance", name = "example" } or nil
function M.find_enclosing_resource()
  local pattern = '^%s*resource%s+"([^"]+)"%s+"([^"]+)"'
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Search backwards from cursor line
  for line_num = cursor_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
    local resource_type, resource_name = line:match(pattern)
    if resource_type and resource_name then
      return { type = resource_type, name = resource_name }
    end
  end

  return nil
end

-- Run terraform plan or apply on the resource at cursor
-- action = "plan" or "apply"
function M.run_terraform(action)
  local resource = M.find_enclosing_resource()

  if not resource then
    vim.notify('No terraform resource found at cursor', vim.log.levels.WARN)
    return
  end

  local target = resource.type .. '.' .. resource.name

  -- Build terraform command, chaining tagging script for apply
  local terraform_cmd
  if action == 'apply' then
    terraform_cmd = string.format('terraform %s -auto-approve -target=%s && ./add_tags/caller.py append', action, target)
  elseif action == 'plan' then
    terraform_cmd = string.format('TF_LOG=DEBUG OCI_GO_SDK_DEBUG=v terraform plan -target=%s', target)
  else
    terraform_cmd = string.format('terraform %s -target=%s', action, target)
  end

  -- Build zellij command with top-right positioning (matching zellij_run.lua pattern)
  -- Use bash -ic to source .bashrc and pick up env vars (API keys, etc.)
  local zellij_cmd = string.format(
    'zellij run --floating --x 50%% --y 0 --width 50%% --height 70%% -- bash -ic %q',
    terraform_cmd
  )

  -- Run asynchronously using jobstart
  vim.fn.jobstart(zellij_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify(string.format('Zellij error (exit %d)', exit_code), vim.log.levels.ERROR)
        end)
      end
    end,
  })

  local notify_msg = action == 'plan'
    and string.format('terraform plan (DEBUG) -target=%s', target)
    or string.format('terraform %s -target=%s', action, target)
  vim.notify(notify_msg, vim.log.levels.INFO)
end

-- Run terraform validate
function M.run_terraform_validate()
  local zellij_cmd = 'zellij run --floating --x 50% --y 0 --width 50% --height 70% -- terraform validate'

  vim.fn.jobstart(zellij_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify(string.format('Zellij error (exit %d)', exit_code), vim.log.levels.ERROR)
        end)
      end
    end,
  })

  vim.notify('terraform validate', vim.log.levels.INFO)
end

-- Find the enclosing terraform module block from cursor position
-- Returns module name or nil
function M.find_enclosing_module()
  local pattern = '^%s*module%s+"([^"]+)"'
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  for line_num = cursor_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1]
    local module_name = line:match(pattern)
    if module_name then
      return module_name
    end
  end
  return nil
end

-- Run terraform plan or apply on the module at cursor with DEBUG logging
-- action = "plan" or "apply"
function M.run_terraform_module(action)
  local module_name = M.find_enclosing_module()

  if not module_name then
    vim.notify('No terraform module found at cursor', vim.log.levels.WARN)
    return
  end

  local target = 'module.' .. module_name

  local terraform_cmd
  if action == 'apply' then
    terraform_cmd = string.format(
      'TF_LOG=DEBUG OCI_GO_SDK_DEBUG=v terraform apply -auto-approve -target=%s',
      target
    )
  else
    terraform_cmd = string.format(
      'TF_LOG=DEBUG OCI_GO_SDK_DEBUG=v terraform %s -target=%s',
      action, target
    )
  end

  -- Build zellij command with top-right positioning (matching run_terraform pattern)
  -- Use bash -ic to source .bashrc and pick up env vars (API keys, etc.)
  local zellij_cmd = string.format(
    'zellij run --floating --x 50%% --y 0 --width 50%% --height 70%% -- bash -ic %q',
    terraform_cmd
  )

  -- Run asynchronously using jobstart
  vim.fn.jobstart(zellij_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify(string.format('Zellij error (exit %d)', exit_code), vim.log.levels.ERROR)
        end)
      end
    end,
  })

  vim.notify(string.format('terraform %s (DEBUG) -target=%s', action, target), vim.log.levels.INFO)
end

-- Run terraform apply -auto-approve on all resources, then run tagging script
function M.run_terraform_all()
  local terraform_cmd = 'terraform apply -auto-approve && ./add_tags/caller.py append'

  -- Build zellij command with top-right positioning (matching zellij_run.lua pattern)
  -- Use bash -ic to source .bashrc and pick up env vars (API keys, etc.)
  local zellij_cmd = string.format(
    'zellij run --floating --x 50%% --y 0 --width 50%% --height 70%% -- bash -ic %q',
    terraform_cmd
  )

  -- Run asynchronously using jobstart
  vim.fn.jobstart(zellij_cmd, {
    on_exit = function(_, exit_code)
      if exit_code ~= 0 then
        vim.schedule(function()
          vim.notify(string.format('Zellij error (exit %d)', exit_code), vim.log.levels.ERROR)
        end)
      end
    end,
  })

  vim.notify('terraform apply -auto-approve + tagging', vim.log.levels.INFO)
end

return M
