---@type vim.lsp.Config
return {
  settings = {
    Lua = {
      runtime = {
        version = "LuaJIT",
      },

      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME,
        },
        maxPreload = 1000,
        preloadFileSize = 150,
        ignoreDir = { ".git", ".gemini", "research", "brain" },
      },

      diagnostics = {
        globals = { "vim" },
      },

      telemetry = {
        enable = false,
      },
    },
  },
}
