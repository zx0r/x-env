---@type vim.lsp.Config
return {
  filetypes = {
    "sh",
    "bash",
    "zsh",
  },
  settings = {
    bashIde = {
      globPattern = "*@(.sh|.inc|.bash|.command|.zsh)",
    },
  },
}
