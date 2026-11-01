---@type vim.lsp.Config
return {
  filetypes = {
    "yaml.ansible",
    "ansible",
  },
  settings = {
    ansible = {
      ansible = {
        path = "ansible",
      },
      executionEnvironment = {
        enabled = false,
      },
      validation = {
        enabled = true,
        lint = {
          enabled = true,
          path = "ansible-lint",
        },
      },
    },
  },
}
