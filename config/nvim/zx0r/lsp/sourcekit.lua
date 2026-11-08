---@type vim.lsp.Config
return {
  cmd = { "sourcekit-lsp" },
  filetypes = { "swift", "objc", "objcpp" },
  root_markers = {
    "buildServer.json",
    ".bsp",
    "*.xcodeproj",
    "*.xcworkspace",
    "compile_commands.json",
    "Package.swift",
    ".git",
  },
  get_language_id = function(_, ftype)
    local map = { objc = "objective-c", objcpp = "objective-cpp" }
    return map[ftype] or ftype
  end,
  capabilities = {
    workspace = {
      didChangeWatchedFiles = {
        dynamicRegistration = true,
        relativePatternSupport = true,
      },
    },
    textDocument = {
      diagnostic = {
        dynamicRegistration = true,
        relatedDocumentSupport = true,
      },
    },
  },
  initialization_options = {
    backgroundIndexing = true,
    backgroundPreparationMode = "enabled",
    cancelTextDocumentRequestsOnEditAndClose = false,
    swiftPublishDiagnosticsDebounceDuration = 0.5,
    swiftPM = {
      configuration = "debug",
    },
  },
}
