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
    keys = {
      { "<c-/>", function() Snacks.terminal() end, desc = "Toggle Terminal" },
      { "<c-_>", function() Snacks.terminal() end, desc = "which_key_ignore" },
    },
  },
  {
    "mrjones2014/smart-splits.nvim",

    opts = {
      move = {
        -- Stop at the edge instead of wrapping to another window.
        at_edge = "stop",
      },
      swap = {
        -- Keep the cursor with the buffer when buffers are swapped.
        move_cursor = true,
      },
    },

    keys = {
      -- ======================================================================
      -- SPATIAL PANE NAVIGATION (Alt + Arrows : Tmux / Mux 2D Grid Parity)
      -- ======================================================================

      {
        "<A-Left>",
        function()
          require("smart-splits").move_cursor_left()
        end,
        mode = { "n", "t" },
        desc = "Focus left (Tmux spatial parity)",
      },

      {
        "<A-Down>",
        function()
          require("smart-splits").move_cursor_down()
        end,
        mode = { "n", "t" },
        desc = "Focus down (Tmux spatial parity)",
      },

      {
        "<A-Up>",
        function()
          require("smart-splits").move_cursor_up()
        end,
        mode = { "n", "t" },
        desc = "Focus up (Tmux spatial parity)",
      },

      {
        "<A-Right>",
        function()
          require("smart-splits").move_cursor_right()
        end,
        mode = { "n", "t" },
        desc = "Focus right (Tmux spatial parity)",
      },

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
      -- BUFFER SWAPPING (Alt + Shift + Arrows & Leader + wHJKL from x0r_old)
      -- ======================================================================

      {
        "<A-S-Left>",
        function()
          require("smart-splits").swap_buf_left()
        end,
        mode = "n",
        desc = "Swap buffer left",
      },

      {
        "<A-S-Down>",
        function()
          require("smart-splits").swap_buf_down()
        end,
        mode = "n",
        desc = "Swap buffer down",
      },

      {
        "<A-S-Up>",
        function()
          require("smart-splits").swap_buf_up()
        end,
        mode = "n",
        desc = "Swap buffer up",
      },

      {
        "<A-S-Right>",
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

  -- ==========================================================================
  -- WINSHIFT (Interactive window split rearrangement)
  -- ==========================================================================
  {
    "sindrets/winshift.nvim",
    cmd = { "WinShift" },
    opts = {
      highlight_moving_win = true,
    },
    keys = {
      { "<leader>ws", "<cmd>WinShift<cr>", desc = "WinShift: rearrange window splits" },
      { "<leader>wX", "<cmd>WinShift swap<cr>", desc = "WinShift: swap windows" },
    },
  },
}

