---@type vim.lsp.Config
return {
  before_init = function(_, config)
    config.settings = config.settings or {}
    config.settings.yaml = config.settings.yaml or {}

    config.settings.yaml.schemas = vim.tbl_deep_extend(
      "force",
      config.settings.yaml.schemas or {},
      require("schemastore").yaml.schemas()
    )
  end,
  settings = {
    redhat = {
      telemetry = {
        enabled = false,
      },
    },
    yaml = {
      keyOrdering = false,
      format = {
        enable = true,
      },
      validate = true,

      schemaStore = {
        enable = false,
        url = "",
      },

      hover = true,
      completion = true,
    },
  },
}
