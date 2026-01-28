-- Terraform plan/apply commands
-- Run terraform targeting the resource at cursor in a zellij floating pane

local M = require('terraform_run')

vim.api.nvim_create_user_command('TerraformPlan', function()
  M.run_terraform('plan')
end, { desc = 'Run terraform plan on resource at cursor' })

vim.api.nvim_create_user_command('TerraformApply', function()
  M.run_terraform('apply')
end, { desc = 'Run terraform apply on resource at cursor' })

vim.api.nvim_create_user_command('TerraformApplyAll', function()
  M.run_terraform_all()
end, { desc = 'Run terraform apply -auto-approve + tagging' })

vim.api.nvim_create_user_command('TerraformValidate', function()
  M.run_terraform_validate()
end, { desc = 'Run terraform validate' })
