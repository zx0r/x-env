-- ============================================================================
-- ~/.config/nvim/lua/plugins/terminal.lua — Terminal / Split Domain
--
-- Responsibilities:
--   - Split/window directional navigation
--   - Split resizing
--   - Buffer swapping between splits
--   - Terminal-mode pane navigation
--
-- Boundaries:
--   navigation.lua -> filesystem / spatial file navigation
--   picker.lua     -> fuzzy discovery / selection
--   ui.lua         -> visual presentation
--   terminal.lua   -> split topology and pane movement
--
-- ============================================================================

return {
{
    "folke/snacks.nvim",
    opts = {
      terminal = {
        enabled = true,
        shell = vim.env.SHELL or "/bin/bash",
        win = {
          style = "terminal",
        },
      },
    },
    keys = {
      { "<c-/>",      function() Snacks.terminal() end, desc = "Toggle Terminal" },
      { "<c-_>",      function() Snacks.terminal() end, desc = "which_key_ignore" },
    },
  },
  {
    "mrjones2014/smart-splits.nvim",
    build = "./kitty/install-kittens.bash",
    event = "VeryLazy",

    opts = {
      -- Stop at the edge instead of wrapping to another window.
      at_edge = "stop",

      -- Multiplexer integration (auto-detects Kitty and Tmux)
      multiplexer_integration = nil,

      -- Keep the cursor with the buffer when buffers are swapped.
      cursor_follows_swapped_bufs = true,

      -- Interactive resize mode.
      resize_mode = {
        quit_key = "<Esc>",

        resize_keys = {
          "h",
          "j",
          "k",
          "l",
        },

        silent = true,
      },
    },

    keys = {
      -- ======================================================================
      -- NORMAL MODE — PANE NAVIGATION (overrides core wincmd with mux support)
      -- ======================================================================

      {
        "<C-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        mode = "n",
        desc = "Focus left",
      },

      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        mode = "n",
        desc = "Focus down",
      },

      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        mode = "n",
        desc = "Focus up",
      },

      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        mode = "n",
        desc = "Focus right",
      },

      -- ======================================================================
      -- TERMINAL MODE — PANE NAVIGATION
      -- ======================================================================

      {
        "<C-h>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        mode = "t",
        desc = "Focus left",
      },

      {
        "<C-j>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        mode = "t",
        desc = "Focus down",
      },

      {
        "<C-k>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        mode = "t",
        desc = "Focus up",
      },

      {
        "<C-l>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        mode = "t",
        desc = "Focus right",
      },

      -- ======================================================================
      -- NORMAL MODE — PANE RESIZING (Alt + hjkl & Ctrl + Arrows from x0r_old)
      -- ======================================================================

      {
        "<C-Left>",
        function()
          require("smart-splits").resize_left()
        end,
        mode = "n",
        desc = "Resize left",
      },

      {
        "<C-Down>",
        function()
          require("smart-splits").resize_down()
        end,
        mode = "n",
        desc = "Resize down",
      },

      {
        "<C-Up>",
        function()
          require("smart-splits").resize_up()
        end,
        mode = "n",
        desc = "Resize up",
      },

      {
        "<C-Right>",
        function()
          require("smart-splits").resize_right()
        end,
        mode = "n",
        desc = "Resize right",
      },

      {
        "<A-h>",
        function()
          require("smart-splits").resize_left()
        end,
        mode = "n",
        desc = "Resize left",
      },

      {
        "<A-j>",
        function()
          require("smart-splits").resize_down()
        end,
        mode = "n",
        desc = "Resize down",
      },

      {
        "<A-k>",
        function()
          require("smart-splits").resize_up()
        end,
        mode = "n",
        desc = "Resize up",
      },

      {
        "<A-l>",
        function()
          require("smart-splits").resize_right()
        end,
        mode = "n",
        desc = "Resize right",
      },

      -- ======================================================================
      -- BUFFER SWAPPING (Alt + Arrows & Leader + wHJKL from x0r_old)
      -- ======================================================================

      {
        "<A-Left>",
        function()
          require("smart-splits").swap_buf_left()
        end,
        mode = "n",
        desc = "Swap buffer left",
      },

      {
        "<A-Down>",
        function()
          require("smart-splits").swap_buf_down()
        end,
        mode = "n",
        desc = "Swap buffer down",
      },

      {
        "<A-Up>",
        function()
          require("smart-splits").swap_buf_up()
        end,
        mode = "n",
        desc = "Swap buffer up",
      },

      {
        "<A-Right>",
        function()
          require("smart-splits").swap_buf_right()
        end,
        mode = "n",
        desc = "Swap buffer right",
      },

      {
        "<leader>wH",
        function()
          require("smart-splits").swap_buf_left()
        end,
        mode = "n",
        desc = "Swap buffer left",
      },

      {
        "<leader>wJ",
        function()
          require("smart-splits").swap_buf_down()
        end,
        mode = "n",
        desc = "Swap buffer down",
      },

      {
        "<leader>wK",
        function()
          require("smart-splits").swap_buf_up()
        end,
        mode = "n",
        desc = "Swap buffer up",
      },

      {
        "<leader>wL",
        function()
          require("smart-splits").swap_buf_right()
        end,
        mode = "n",
        desc = "Swap buffer right",
      },
    },
  },

  -- ==========================================================================
  -- Kitty terminal scrollback
  -- ==========================================================================

  {
    "mikesmithgh/kitty-scrollback.nvim",

    lazy = true,

    cmd = {
      "KittyScrollbackGenerateKittens",
      "KittyScrollbackCheckHealth",
    },

    event = {
      "User KittyScrollbackLaunch",
    },

    opts = {
      callbacks = {
        after_ready = function()
          vim.api.nvim_set_hl(
            0,
            "KittyScrollbackNvimNormal",
            { bg = "NONE" }
          )

          vim.api.nvim_set_hl(
            0,
            "KittyScrollbackNvimWinBar",
            { bg = "NONE" }
          )

          vim.api.nvim_set_hl(
            0,
            "KittyScrollbackNvimWinBarShadow",
            { bg = "NONE" }
          )
        end,
      },
    },
  },
}
