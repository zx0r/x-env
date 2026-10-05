-- ============================================================================
-- plugins/ui.lua — Shared UI Integration & Infrastructure
--
-- Responsibility:
--   • Canonical Snacks.nvim plugin identity (lazy = false, priority = 1000)
--   • Shared editor presentation primitives (statuscolumn, words, scroll, input, zen, dim)
--   • Large-file interceptor delegation (snacks.bigfile -> core/guard.lua)
--   • Lightweight icon provider integration (mini.icons)
--   • Standard UI toggle mappings (VeryLazy)
--
-- Non-responsibility:
--   • Dashboard & Launcher         → ui-dashboard.lua
--   • Notifier, Telemetry & Noice  → ui-messages.lua
--   • Which-Key Keymap Discovery   → ui-discovery.lua
--   • Statusline & Modicator       → ui-status.lua
--   • Visual Styles & Color Policy → ui-theme.lua
--   • Scope & Indent               → syntax.lua
--   • Bigfile Runtime Policy       → core/guard.lua (sole governor)
--
-- Neovim >= 0.12
-- ============================================================================

return {
  -- ========================================================================
  -- mini.icons — Icon Provider
  -- ========================================================================
  {
    "echasnovski/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- ========================================================================
  -- snacks.nvim — Canonical Shared UI Integration
  -- ========================================================================
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,

    opts = {
      bigfile = {
        enabled = true,
        notify = false,
        size = 1024 * 1024, -- 1MB (Tier 1 threshold)
        setup = function(ctx)
          require("core.guard").setup(ctx)
        end,
      },

      statuscolumn = {
        enabled = true,
        left = { "mark", "sign" },
        right = { "fold", "git" },
        folds = { open = false, git_hl = false },
        git = { patterns = { "GitSign", "MiniDiffSign" } },
        refresh = 50,
      },

      quickfile = { enabled = true },

      words = { enabled = true, debounce = 200, notify_jump = false, notify_end = true },

      scroll = {
        enabled = true,
        animate = { enabled = false },
        filter = function(buf)
          return vim.api.nvim_buf_is_valid(buf)
            and vim.g.snacks_scroll ~= false
            and vim.b[buf].snacks_scroll ~= false
            and vim.bo[buf].buftype == ""
            and not vim.b[buf].large_file
        end,
      },

      input = { enabled = true },
      zen = { enabled = true, win = { width = 120, backdrop = { transparent = true, blend = 40 } } },
      dim = { enabled = true },
      image = { enabled = true },
    },

    keys = {
      {
        "<leader>z",
        function()
          Snacks.zen()
        end,
        desc = "Zen mode",
      },
      {
        "<leader>Z",
        function()
          Snacks.zen.zoom()
        end,
        desc = "Zoom",
      },
      {
        "<leader>bd",
        function()
          Snacks.bufdelete()
        end,
        desc = "Delete Buffer",
      },
    },

    config = function(_, opts)
      require("snacks").setup(opts)

      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          if vim.env.NVIM_DEBUG then
            _G.dd = function(...)
              Snacks.debug.inspect(...)
            end
            vim.print = _G.dd
          end

          Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
          Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
          Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
          Snacks.toggle.diagnostics():map("<leader>ud")
          Snacks.toggle.line_number():map("<leader>ul")
          Snacks.toggle.treesitter():map("<leader>uT")
          Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
          Snacks.toggle.inlay_hints():map("<leader>uh")
          Snacks.toggle.indent():map("<leader>ug")
          Snacks.toggle.dim():map("<leader>uD")
        end,
      })
    end,
  },

  -- ========================================================================
  -- scrollEOF.nvim — Smooth viewport scrolling past end of buffer
  -- ========================================================================
  {
    "Aasim-A/scrollEOF.nvim",
    event = "CursorMoved",
    opts = {},
  },
}
