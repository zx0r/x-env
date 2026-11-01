---@type vim.lsp.Config
return {
  root_markers = {
    "package.json",
    ".git",
  },
  filetypes = {
    "css",
    "scss",
    "less",
  },
  settings = {
    css = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
        compatibleVendorPrefixes = "ignore",
        vendorPrefix = "ignore",
        unknownVendorSpecificProperties = "ignore",
        duplicateProperties = "warning",
        emptyRules = "warning",
        importStatement = "warning",
      },
    },
    scss = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
        compatibleVendorPrefixes = "ignore",
        vendorPrefix = "ignore",
        unknownVendorSpecificProperties = "ignore",
        duplicateProperties = "warning",
        emptyRules = "warning",
        importStatement = "warning",
      },
    },
    less = {
      validate = true,
      lint = {
        unknownAtRules = "ignore",
        compatibleVendorPrefixes = "ignore",
        vendorPrefix = "ignore",
        unknownVendorSpecificProperties = "ignore",
        duplicateProperties = "warning",
        emptyRules = "warning",
        importStatement = "warning",
      },
    },
  },
}
