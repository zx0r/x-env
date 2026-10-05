-- ============================================================================
-- lua/plugins/language.lua — Language Intelligence & Toolchain Domain
--
-- Neovim >= 0.12
--
-- Responsibilities:
--   - Native Neovim LSP orchestration
--   - Shared LSP capabilities
--   - Diagnostics presentation
--   - LspAttach lifecycle policy
--   - Language-server activation
--   - External language-tool provisioning via Mason
--   - Rust language integration
--
-- Non-responsibilities:
--   - Formatting execution        -> coding.lua / conform.nvim
--   - Linting execution           -> coding.lua / nvim-lint
--   - Debugging                   -> debug.lua / DAP
--   - Git / VCS                   -> vcs.lua
--   - Completion                  -> coding.lua / blink.cmp
--   - UI / navigation             -> ui.lua
--
-- Server-specific LSP overrides belong strictly in:
--
--   lsp/<server>.lua (Neovim >= 0.12 native vim.lsp.config boundary)
--
-- Example:
--
--   lsp/lua_ls.lua
--   lsp/jsonls.lua
--   lsp/yamlls.lua
--
-- ============================================================================

return {


  -- ==========================================================================
  -- NATIVE LSP
  -- ==========================================================================

  {
    "neovim/nvim-lspconfig",

    event = {
      "BufReadPre",
      "BufNewFile",
    },

    dependencies = {
      "b0o/schemastore.nvim",
    },

    config = function()
      -- ======================================================================
      -- Shared LSP capabilities (Zero-Overhead: Pre-baked blink capabilities)
      -- Avoids synchronous require('blink.cmp') on BufReadPre (saves ~25ms).
      -- Full blink engine loads strictly on InsertEnter as configured.
      -- ======================================================================

      local capabilities
      if package.loaded["blink.cmp"] then
        capabilities = require("blink.cmp").get_lsp_capabilities()
      else
        capabilities = vim.lsp.protocol.make_client_capabilities()
        capabilities.textDocument.completion.completionItem = {
          commitCharactersSupport = false,
          deprecatedSupport = true,
          documentationFormat = { "markdown", "plaintext" },
          insertReplaceSupport = true,
          insertTextModeSupport = { valueSet = { 1 } },
          labelDetailsSupport = true,
          preselectSupport = false,
          resolveSupport = {
            properties = { "documentation", "detail", "additionalTextEdits", "command", "data" },
          },
          snippetSupport = true,
          tagSupport = { valueSet = { 1 } },
        }
        capabilities.textDocument.completion.completionList = {
          itemDefaults = { "commitCharacters", "editRange", "insertTextFormat", "insertTextMode", "data" },
        }
        capabilities.textDocument.completion.contextSupport = true
        capabilities.textDocument.completion.insertTextMode = 1
      end

      vim.lsp.config("*", {
        capabilities = capabilities,
      })


      -- ======================================================================
      -- LSP ATTACH POLICY
      -- ======================================================================

      local attach_group = vim.api.nvim_create_augroup(
        "core_lsp_attach",
        { clear = true }
      )

      vim.api.nvim_create_autocmd("LspAttach", {
        group = attach_group,

        callback = function(event)
          local bufnr = event.buf

          local client = vim.lsp.get_client_by_id(
            event.data.client_id
          )

          if not client then
            return
          end

          -- ==================================================================
          -- Large-file protection
          -- ==================================================================

          if vim.b[bufnr].large_file then
            vim.lsp.buf_detach_client(bufnr, client.id)
            return
          end

          -- ==================================================================
          -- Inlay hints
          -- ==================================================================

          if client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, {
              bufnr = bufnr,
            })
          end

          -- ==================================================================
          -- Document highlighting
          -- ==================================================================

          if client:supports_method("textDocument/documentHighlight") then
            local highlight_group = vim.api.nvim_create_augroup(
              "core_lsp_highlight_" .. bufnr,
              { clear = true }
            )

            vim.api.nvim_create_autocmd(
              {
                "CursorHold",
                "CursorHoldI",
              },
              {
                group = highlight_group,
                buffer = bufnr,

                callback = function()
                  if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.lsp.buf.document_highlight()
                  end
                end,
              }
            )

            vim.api.nvim_create_autocmd(
              {
                "CursorMoved",
                "CursorMovedI",
              },
              {
                group = highlight_group,
                buffer = bufnr,

                callback = function()
                  if vim.api.nvim_buf_is_valid(bufnr) then
                    vim.lsp.buf.clear_references()
                  end
                end,
              }
            )
          end

          -- ==================================================================
          -- Buffer-local LSP navigation
          --
          -- These are capabilities of the language layer.
          -- ==================================================================

          local map = vim.keymap.set

          map("n", "gd", vim.lsp.buf.definition, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Go to definition",
          })

          map("n", "gD", vim.lsp.buf.declaration, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Go to declaration",
          })

          map("n", "gr", vim.lsp.buf.references, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Find references",
          })

          map("n", "gi", vim.lsp.buf.implementation, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Go to implementation",
          })

          map("n", "K", vim.lsp.buf.hover, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Hover",
          })

          map("n", "<leader>rn", vim.lsp.buf.rename, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Rename",
          })

          map("n", "<leader>ca", vim.lsp.buf.code_action, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Code action",
          })

          map("n", "<leader>ds", vim.lsp.buf.document_symbol, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Document symbols",
          })

          map("n", "<leader>lS", vim.lsp.buf.workspace_symbol, {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Workspace symbols",
          })

          map("n", "<leader>clr", "<cmd>LspRestart<cr>", {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Restart server",
          })

          map("n", "<leader>cli", "<cmd>LspInfo<cr>", {
            buffer = bufnr,
            silent = true,
            desc = "LSP: Server info",
          })

          -- IMPORTANT:
          -- Formatting intentionally does NOT live here.
          --
          -- <leader>lf is owned by coding.lua / conform.nvim.
        end,
      })

      -- ======================================================================
      -- ENABLED LANGUAGE SERVERS
      --
      -- Dynamically enable only installed language servers.
      -- Prevents Neovim >= 0.12 from attempting to spawn non-existent binaries
      -- on FileType events, eliminating startup microstutters and transport errors.
      -- ======================================================================

      local servers = {
        lua_ls = "lua-language-server",
        basedpyright = { "basedpyright-langserver", "basedpyright" },
        gopls = "gopls",
        ts_ls = "typescript-language-server",
        tailwindcss = "tailwindcss-language-server",
        emmet_language_server = "emmet-language-server",
        html = "vscode-html-language-server",
        cssls = "vscode-css-language-server",
        nil_ls = "nil",
        yamlls = "yaml-language-server",
        jsonls = "vscode-json-language-server",
        taplo = "taplo",
        terraformls = "terraform-ls",
        bashls = "bash-language-server",
        fish_lsp = "fish-lsp",
        dockerls = "docker-langserver",
        docker_compose_language_service = "docker-compose-langserver",
        sqls = "sqls",
        marksman = "marksman",
      }

      local enabled = {}
      for server, bins in pairs(servers) do
        local is_installed = false
        if type(bins) == "table" then
          for _, b in ipairs(bins) do
            if vim.fn.executable(b) == 1 then
              is_installed = true
              break
            end
          end
        else
          is_installed = (vim.fn.executable(bins) == 1)
        end

        if is_installed then
          table.insert(enabled, server)
        end
      end

      vim.lsp.enable(enabled)

      -- Post-enable hardening: strip markdown and astro-markdown from tailwindcss
      -- In Neovim >= 0.12, vim.lsp.enable() initializes lsp._enabled_configs[name].
      -- Mutating the resolved table post-enable guarantees that neither nvim-lspconfig
      -- nor runtimepath can re-inject markdown or astro-markdown into active buffer watchers.
      local tc = vim.lsp.config["tailwindcss"]
      if tc and tc.filetypes then
        tc.filetypes = vim.tbl_filter(function(ft)
          return ft ~= "markdown" and ft ~= "astro-markdown"
        end, tc.filetypes)
      end
    end,
  },

  -- ==========================================================================
  -- RUST
  --
  -- rustaceanvim owns Rust language tooling lifecycle.
  --
  -- rust-analyzer is intentionally NOT included in vim.lsp.enable().
  --
  -- Rust-specific settings live in rustaceanvim configuration because the
  -- plugin owns the Rust LSP lifecycle.
  -- ==========================================================================

  {
    "mrcjkb/rustaceanvim",

    ft = {
      "rust",
    },

    init = function()
      -- Defer configuration evaluation until the rustaceanvim plugin is actually loaded
      vim.g.rustaceanvim = function()
        return {
          server = {
            cmd = function()
              local candidates = {
                vim.fn.stdpath("data") .. "/mason/bin/rust-analyzer",
                vim.fn.expand("~/.local/share/nvim/mason/bin/rust-analyzer"),
                vim.fn.expand("~/.cargo/bin/rust-analyzer"),
                "rust-analyzer"
              }
              for _, path in ipairs(candidates) do
                if vim.fn.executable(path) == 1 or vim.uv.fs_stat(path) then
                  return { path }
                end
              end
              return { "rust-analyzer" }
            end,

            capabilities = vim.lsp.protocol.make_client_capabilities(),

            on_attach = function(client, bufnr)
              -- Merge blink.cmp capabilities once available
              local ok, blink = pcall(require, "blink.cmp")
              if ok then
                local caps = blink.get_lsp_capabilities()
                client.config.capabilities = vim.tbl_deep_extend("force", client.config.capabilities or {}, caps)
              end
            end,

            default_settings = {
              ["rust-analyzer"] = {
                cargo = {
                  allFeatures = true,
                  loadOutDirsFromCheck = true,
                },

                check = {
                  allFeatures = true,
                  command = "clippy",
                  extraArgs = {
                    "--no-deps",
                  },
                },
                checkOnSave = {
                  allFeatures = true,
                  command = "clippy",
                  extraArgs = {
                    "--no-deps",
                  },
                },

              procMacro = {
                enable = true,
              },

              inlayHints = {
                bindingModeHints = {
                  enable = false,
                },

                closingBraceHints = {
                  enable = true,
                  minLines = 25,
                },

                closureReturnTypeHints = {
                  enable = "never",
                },

                lifetimeElisionHints = {
                  enable = "never",
                },

                parameterHints = {
                  enable = true,
                },

                reborrowHints = {
                  enable = "never",
                },

                renderColons = {
                  enable = true,
                },

                typeHints = {
                  enable = true,
                  hideClosureInitialization = false,
                  hideNamedConstructor = false,
                },
              },
            },
          },
        },

        tools = {
          hover_actions = {
            auto_focus = true,
          },

          float_win_config = {
            border = "rounded",
          },
        },
      }
      end
    end,
  },

  -- ==========================================================================
  -- INLINE LSP RENAME (with live preview)
  -- ==========================================================================
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
    keys = {
      {
        "<leader>cr",
        function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Rename (inc-rename)",
      },
    },
  },

  -- ==========================================================================
  -- CODE ACTION PREVIEW (Full diff preview via Telescope from x0r_old)
  -- ==========================================================================
  {
    "aznhe21/actions-preview.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = "LspAttach",
    opts = {
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.6,
          height = 0.7,
          prompt_position = "top",
          preview_cutoff = 20,
          preview_height = function(_, _, max_lines)
            return max_lines - 15
          end,
        },
      },
    },
    keys = {
      {
        "<leader>ca",
        function()
          require("actions-preview").code_actions()
        end,
        mode = { "n", "v" },
        desc = "Code Action Preview",
      },
    },
  },

  -- ==========================================================================
  -- RUST CRATES DEPENDENCY MANAGEMENT (Full 11-key map from x0r_old)
  -- ==========================================================================
  {
    "Saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    opts = {
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
    keys = {
      { "<leader>pru", function() require("crates").update_crate() end, desc = "Update Crate" },
      { "<leader>pru", mode = "v", function() require("crates").update_crates() end, desc = "Update Crates" },
      { "<leader>pra", function() require("crates").update_all_crates() end, desc = "Update All Crates" },
      { "<leader>prU", function() require("crates").upgrade_crate() end, desc = "Upgrade Crate" },
      { "<leader>prU", mode = "v", function() require("crates").upgrade_crates() end, desc = "Upgrade Crates" },
      { "<leader>prA", function() require("crates").upgrade_all_crates() end, desc = "Upgrade All Crates" },
      { "<leader>prt", function() require("crates").expand_plain_crate_to_inline_table() end, desc = "Extract into Inline Table" },
      { "<leader>prT", function() require("crates").extract_crate_into_table() end, desc = "Extract into Table" },
      { "<leader>prh", function() require("crates").open_homepage() end, desc = "Homepage" },
      { "<leader>prr", function() require("crates").open_repository() end, desc = "Repo" },
      { "<leader>prd", function() require("crates").open_documentation() end, desc = "Documentation" },
      { "<leader>prc", function() require("crates").open_crates_io() end, desc = "Crates.io" },
      { "<leader>prR", function() require("crates").reload() end, desc = "Reload" },
    },
  },

  -- ==========================================================================
  -- PYTHON REQUIREMENTS MANAGEMENT
  -- ==========================================================================
  {
    "MeanderingProgrammer/py-requirements.nvim",
    event = {
      "BufRead requirements.txt",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {},
    keys = {
      { "<leader>ppu", function() require("py-requirements").upgrade() end, desc = "Update Package" },
      { "<leader>ppi", function() require("py-requirements").show_description() end, desc = "Package Info" },
      { "<leader>ppa", function() require("py-requirements").upgrade_all() end, desc = "Update All Packages" },
    },
  },

  -- ==========================================================================
  -- NEODIM (Dim unused tokens via LSP)
  -- ==========================================================================
  {
    "zbirenbaum/neodim",
    event = "LspAttach",
    opts = {
      alpha = 0.60,
    },
  },

  -- ==========================================================================
  -- GARBAGE DAY (LSP garbage collector to reclaim idle memory)
  -- ==========================================================================
  {
    "zeioth/garbage-day.nvim",
    event = "LspAttach",
    opts = {
      notifications = false,
      grace_period = 60 * 10,
    },
  },
}
