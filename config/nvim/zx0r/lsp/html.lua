---@type vim.lsp.Config
return {
  filetypes = {
    "html",
    "templ",
  },
  settings = {
    html = {
      format = {
        enable = false,
      },
      hover = {
        documentation = true,
        references = true,
      },
    },
  },
}
