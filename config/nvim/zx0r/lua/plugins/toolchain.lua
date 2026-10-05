-- ============================================================================
-- plugins/toolchain.lua — External Toolchain Domain
-- ============================================================================
--
-- Responsibility:
--   - Mason, tool installation, binary discovery, registry
--   - External language-tool provisioning
--   - Native mason-registry lifecycle without notification spam
--
-- Neovim >= 0.12
-- ============================================================================

return {

  -- ==========================================================================
  -- MASON
  -- External language-tool provisioning via native registry
  -- ==========================================================================

  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonToolsInstall", "MasonToolsUpdate" },
    opts_extend = { "ensure_installed" },
    opts = {
      ui = {
        border = "rounded",
      },

      -- Keep Mason's binaries available to native LSP, Conform, nvim-lint, DAP
      PATH = "prepend",

      ensure_installed = {

        -- --------------------------------------------------------------------
        -- Language Servers
        -- --------------------------------------------------------------------

        "lua-language-server",
        "basedpyright",
        "gopls",
        "typescript-language-server",
        "tailwindcss-language-server",
        "emmet-language-server",
        "html-lsp",
        "css-lsp",
        "rust-analyzer",

        "terraform-ls",

        "bash-language-server",
        "fish-lsp",
        "yaml-language-server",
        "json-lsp",

        "dockerfile-language-server",
        "docker-compose-language-service",

        "sqls",
        "marksman",

        -- --------------------------------------------------------------------
        -- Formatters (consumed by coding.lua / conform.nvim)
        -- --------------------------------------------------------------------

        "stylua",
        "prettier",
        "ruff",
        "shfmt",
        "gofumpt",
        "goimports-reviser",
        "golines",
        "terraform",
        "taplo",
        "buf",
        "sql-formatter",

        -- --------------------------------------------------------------------
        -- Linters (consumed by coding.lua / nvim-lint)
        -- --------------------------------------------------------------------

        "luacheck",
        "eslint_d",
        "shellcheck",
        "hadolint",
        "tflint",
        "markdownlint",
        "yamllint",
        "golangci-lint",

        -- --------------------------------------------------------------------
        -- Debuggers (consumed by debug.lua / DAP)
        -- --------------------------------------------------------------------

        "delve",
        "codelldb",
      },
    },

    config = function(_, opts)
      require("mason").setup(opts)

      local mr = require("mason-registry")

      mr:on("package:install:success", function()
        vim.defer_fn(function()
          pcall(function()
            require("lazy.core.handler.event").trigger({
              event = "FileType",
              buf = vim.api.nvim_get_current_buf(),
            })
          end)
        end, 100)
      end)

      local function install_tools()
        mr.refresh(function()
          local needed = 0
          for _, tool in ipairs(opts.ensure_installed or {}) do
            local ok, p = pcall(mr.get_package, tool)
            if ok and p and not p:is_installed() and not p:is_installing() then
              needed = needed + 1
              p:install()
            end
          end
          if needed == 0 then
            vim.notify("All Mason tools are already installed", vim.log.levels.INFO, {
              id = "mason_progress",
              title = "Mason Toolchain",
              timeout = 3000,
              opts = function(notif)
                notif.icon = " "
              end,
            })
          end
        end)
      end

      vim.api.nvim_create_user_command("MasonToolsInstall", install_tools, {
        desc = "Install all configured Mason tools",
      })

      vim.api.nvim_create_user_command("MasonToolsUpdate", function()
        mr.refresh(function()
          for _, tool in ipairs(opts.ensure_installed or {}) do
            local ok, p = pcall(mr.get_package, tool)
            if ok and p and not p:is_installing() then
              p:install({ version = "latest" })
            end
          end
        end)
      end, {
        desc = "Update all configured Mason tools",
      })
    end,
  },

}
