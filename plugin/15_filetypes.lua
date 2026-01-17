-- Filetype detection for template files (Jinja2, Ansible, Helm)

vim.filetype.add({
  extension = {
    j2 = "jinja2",
    jinja = "jinja2",
    jinja2 = "jinja2",
    yaml = "yaml.jinja2",
    yml = "yaml.jinja2",
  },
  pattern = {
    -- Helm (higher priority than default yaml.jinja2)
    [".*/templates/.*%.ya?ml"] = "helm",
    [".*/templates/.*%.tpl"] = "helm",
    ["helmfile.*%.ya?ml"] = "helm",
  },
})
