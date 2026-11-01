---@type vim.lsp.Config
return {
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
    ".git",
  },
  settings = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "standard",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
        reportMissingTypeStubs = false,
        diagnosticSeverityOverrides = {
          reportUnusedCallResult = "information",
          reportUnusedExpression = "information",
          reportUnknownMemberType = "none",
          reportUnknownLambdaType = "none",
          reportUnknownParameterType = "none",
          reportMissingParameterType = "none",
          reportUnknownVariableType = "none",
          reportUnknownArgumentType = "none",
          reportAny = "none",
        },
      },
    },
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      },
    },
  },
}
