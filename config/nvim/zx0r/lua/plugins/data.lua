-- ============================================================================
-- lua/plugins/data.lua — Data & Database Domain
-- Neovim >= 0.12
--
-- Domains:
--   Molten       → Jupyter / interactive notebook execution
--   image.nvim   → terminal image rendering for Molten
--   Dadbod       → database client
--   Dadbod UI    → database explorer
--
-- Loading policy:
--   Zero startup cost.
--   Data tooling loads only for relevant filetypes or explicit commands.
-- ============================================================================

return {
  -- ── Molten: Jupyter / interactive code execution ─────────────────────────
  {
    "benlubas/molten-nvim",

    cmd = {
      "MoltenInit",
      "MoltenInfo",
      "MoltenEvaluateOperator",
      "MoltenEvaluateLine",
      "MoltenEvaluateVisual",
      "MoltenReevaluateCell",
      "MoltenDelete",
      "MoltenShowOutput",
      "MoltenEnterOutput",
    },

    build = ":UpdateRemotePlugins",

    dependencies = {
      { "3rd/image.nvim", lazy = true,
        enabled = function()
          local term = vim.env.TERM or ""
          local term_program = vim.env.TERM_PROGRAM or ""

          return term:match("kitty")
            or term_program:match("WezTerm")
            or term_program:match("Ghostty")
            or term_program:match("ghostty")
            or vim.env.KITTY_WINDOW_ID ~= nil
            or vim.env.SNACKS_KITTY ~= nil
        end,

        opts = {
          backend = "kitty",

          integrations = {
            markdown = {
              enabled = false,
            },
            neorg = {
              enabled = false,
            },
          },

          max_width = 100,
          max_height = 12,

          max_width_window_percentage = math.huge,
          max_height_window_percentage = math.huge,

          window_overlap_clear_enabled = true,

          window_overlap_clear_ft_ignore = {
            "cmp_menu",
            "cmp_docs",
            "",
          },
        },
      },
    },

    config = function()
      -- These are global Molten options and must exist before the
      -- remote-plugin initialization takes place.
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_output_virt_lines = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true

      -- image.nvim is only useful in terminals capable of inline images.
      local term = vim.env.TERM or ""
      local term_program = vim.env.TERM_PROGRAM or ""

      if term:match("kitty")
        or term_program:match("WezTerm")
        or term_program:match("Ghostty")
        or term_program:match("ghostty")
      then
        vim.g.molten_image_provider = "image.nvim"
      else
        vim.g.molten_image_provider = "none"
      end
    end,

    keys = {
      {
        "<leader>mi",
        "<cmd>MoltenInit<cr>",
        desc = "Molten: Initialize kernel",
      },
      {
        "<leader>me",
        "<cmd>MoltenEvaluateOperator<cr>",
        desc = "Molten: Evaluate operator",
      },
      {
        "<leader>ml",
        "<cmd>MoltenEvaluateLine<cr>",
        desc = "Molten: Evaluate line",
      },
      {
        "<leader>mv",
        "<cmd>MoltenEvaluateVisual<cr>",
        mode = "v",
        desc = "Molten: Evaluate selection",
      },
      {
        "<leader>mr",
        "<cmd>MoltenReevaluateCell<cr>",
        desc = "Molten: Re-evaluate cell",
      },
      {
        "<leader>md",
        "<cmd>MoltenDelete<cr>",
        desc = "Molten: Delete output",
      },
      {
        "<leader>mo",
        "<cmd>MoltenShowOutput<cr>",
        desc = "Molten: Show output",
      },
    },
  },

  -- ── Dadbod: Database client ──────────────────────────────────────────────
  {
    "tpope/vim-dadbod",

    cmd = {
      "DB",
    },

    lazy = true,
  },

  -- ── Dadbod completion ────────────────────────────────────────────────────
  {
    "kristijanhusak/vim-dadbod-completion",

    ft = {
      "sql",
      "mysql",
      "plsql",
    },

    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
    },

    lazy = true,
  },

  -- ── SQL uppercase keywords ───────────────────────────────────────────────
  {
    "jsborjesson/vim-uppercase-sql",
    ft = {
      "sql",
      "mysql",
      "plsql",
    },
  },

  -- ── Dadbod UI: Database explorer ─────────────────────────────────────────
  {
    "kristijanhusak/vim-dadbod-ui",

    cmd = {
      "DBUI",
      "DBUIToggle",
      "DBUIAddConnection",
      "DBUIFindBuffer",
    },

    keys = {
      {
        "<leader>D",
        "<cmd>DBUIToggle<cr>",
        desc = "Database: Toggle explorer",
      },
    },

    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", lazy = true },
    },

    config = function()
      -- Dadbod UI global configuration.
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_force_echo_notifications = 1

      vim.g.db_ui_win_position = "right"
      vim.g.db_ui_winwidth = 40
    end,
  },

  -- ── JQX: Interactive JSON/YAML querying ──────────────────────────────────
  {
    "gennaro-tedesco/nvim-jqx",
    cmd = { "JqxList", "JqxQuery" },
    keys = {
      { "<leader>cj", "<cmd>JqxList<cr>", desc = "Jqx List" },
    },
  },

  -- ── Kulala: Minimal REST / HTTP Client ───────────────────────────────────
  {
    "mistweaverco/kulala.nvim",
    ft = { "http", "rest" },
    keys = {
      { "<leader>rr", function() require("kulala").run() end, desc = "HTTP: Send request" },
      { "<leader>rt", function() require("kulala").toggle_view() end, desc = "HTTP: Toggle headers/body" },
      { "<leader>ri", function() require("kulala").inspect() end, desc = "HTTP: Inspect request" },
      { "<leader>rc", function() require("kulala").copy() end, desc = "HTTP: Copy as cURL" },
    },
    opts = {
      icons = {
        inlay = {
          loading = "󰔟",
          done = " ",
          error = " ",
        },
        lualine = " ",
      },
    },
  },
}
