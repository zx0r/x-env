-- ============================================================================
-- plugins/ui-status.lua — Status Telemetry & Mode Presentation Domain
--
-- Responsibility:
--   • Statusline telemetry presentation (nvim-lualine/lualine.nvim)
--   • Mode-aware line number rendering (mawkler/modicator.nvim)
--   • Active LSP server indicator (passive projection view)
--
-- Non-responsibility:
--   • Diagnostic model & policy (owned strictly by diagnostics.lua)
--   • In-place progress & notifications (owned strictly by ui-messages.lua)
--
-- Neovim >= 0.12
-- ============================================================================

return {
  -- ========================================================================
  -- lualine.nvim — Statusline (theme inherited from environment-x)
  -- ========================================================================
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      local mode = {
        "mode",
        fmt = function(value)
          local modes = {
            NORMAL = "󰘳 NORMAL",
            INSERT = "󰏫 INSERT",
            VISUAL = "󰈈 VISUAL",
            ["V-LINE"] = "󰈈 V-LINE",
            ["V-BLOCK"] = "󰈈 V-BLOCK",
            REPLACE = "󰛔 REPLACE",
            ["V-REPLACE"] = "󰛔 V-REPLACE",
            COMMAND = "󰘳 COMMAND",
            TERMINAL = "󰆍 TERMINAL",
            SELECT = "󰈈 SELECT",
            ["S-LINE"] = "󰈈 S-LINE",
            ["S-BLOCK"] = "󰈈 S-BLOCK",
          }
          return modes[value] or value
        end,
        padding = { left = 1, right = 1 },
      }

      local filename = {
        "filename",
        path = 0,
        shorting_target = 45,
        file_status = true,
        symbols = { modified = "", readonly = " 󰌾", unnamed = "[No Name]", newfile = " ＋" },
        fmt = function(str)
          return (str:gsub("%s+$", ""))
        end,
        color = "LualineFilename",
        padding = { left = 0, right = 0 },
      }

      -- Diagnostic Consumer Projection (Variant 1: FontAwesome)
      local diagnostics = {
        "diagnostics",
        sources = { "nvim_diagnostic" },
        sections = { "error", "warn", "info", "hint" },
        symbols = { error = " ", warn = " ", info = " ", hint = " " },
        diagnostics_color = {
          error = "DiagnosticError",
          warn = "DiagnosticWarn",
          info = "DiagnosticInfo",
          hint = "DiagnosticHint",
        },
        colored = true,
        update_in_insert = false,
        padding = { left = 1, right = 1 },
      }

      -- Passive LSP Indicator: lists attached clients without duplicating progress HUD
      local lsp = {
        function()
          local buf_clients = vim.lsp.get_clients({ bufnr = 0 })
          if #buf_clients == 0 then
            return ""
          end

          local names = {}
          for _, client in ipairs(buf_clients) do
            table.insert(names, client.name)
          end

          return "󰒋 " .. table.concat(names, ", ")
        end,
        color = "LualineLsp",
        padding = { left = 1, right = 1 },
      }

      local recording = {
        function()
          local register = vim.fn.reg_recording()
          if register == "" then
            return ""
          end
          return "󰑋 @" .. register
        end,
        cond = function()
          return vim.fn.reg_recording() ~= ""
        end,
        color = "LualineRecording",
        padding = { left = 0, right = 0 },
      }

      local search = {
        "searchcount",
        maxcount = 999,
        timeout = 500,
        color = "LualineSearch",
        padding = { left = 0, right = 0 },
      }

      local encoding = {
        "encoding",
        fmt = string.upper,
        color = "LualineEncoding",
        padding = { left = 1, right = 1 },
      }

      local location = {
        "location",
        color = "LualineLocation",
        padding = { left = 1, right = 1 },
      }

      local progress = {
        "progress",
        color = "LualineProgress",
        padding = { left = 1, right = 1 },
      }

      return {
        options = {
          theme = {
            normal = { a = "LualineNormalA", b = "LualineNormalB", c = "LualineNormalC" },
            insert = { a = "LualineInsertA", b = "LualineInsertB", c = "LualineInsertC" },
            visual = { a = "LualineVisualA", b = "LualineVisualB", c = "LualineVisualC" },
            replace = { a = "LualineReplaceA", b = "LualineReplaceB", c = "LualineReplaceC" },
            command = { a = "LualineCommandA", b = "LualineCommandB", c = "LualineCommandC" },
            inactive = { a = "LualineInactiveA", b = "LualineInactiveB", c = "LualineInactiveC" },
          },
          icons_enabled = true,
          component_separators = { left = " ", right = " " },
          section_separators = { left = " ", right = " " },
          globalstatus = true,
          always_divide_middle = true,
          disabled_filetypes = {
            statusline = {
              "snacks_dashboard",
              "neo-tree",
              "NvimTree",
              "TelescopePrompt",
              "lazy",
              "mason",
              "help",
              "qf",
            },
          },
          refresh = {
            statusline = 200,
            tabline = 1000,
            winbar = 1000,
            events = { "ModeChanged", "WinEnter", "BufEnter", "BufWritePost" },
          },
        },

        sections = {
          lualine_a = { mode },
          lualine_b = {},
          lualine_c = {
            { "filetype", icon_only = true, colored = true, separator = "", padding = { left = 1, right = 0 } },
            filename,
            diagnostics,
          },
          lualine_x = {
            recording,
            search,
            lsp,
          },
          lualine_y = {
            encoding,
            { "selectioncount", color = "LualineSearch" },
            progress,
          },
          lualine_z = {
            location,
          },
        },

        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = {
            { "filetype", icon_only = true, colored = true, separator = "", padding = { left = 1, right = 0 } },
            filename,
          },
          lualine_x = { location },
          lualine_y = {},
          lualine_z = {},
        },

        extensions = { "neo-tree", "lazy", "mason", "trouble", "quickfix", "fzf" },
      }
    end,
  },

  -- ========================================================================
  -- modicator.nvim — Mode-aware line numbers
  -- ========================================================================
  {
    "mawkler/modicator.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
