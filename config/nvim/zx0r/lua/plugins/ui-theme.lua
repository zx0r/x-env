-- ============================================================================
-- plugins/ui-theme.lua — Visual Styling & Color Policy Domain
--
-- Responsibility:
--   • Inline color visualization (nvim-highlight-colors)
--   • Window border styling policy (macOS HIG rounded borders)
--   • Shared visual styles for floating windows and notifications
--
-- Neovim >= 0.12
-- ============================================================================

return {
  -- ========================================================================
  -- Inline Color Visualization
  -- ========================================================================
  {
    "brenoprata10/nvim-highlight-colors",
    event = "VeryLazy",
    opts = {
      render = "background",
      enable_named_colors = true,
      enable_tailwind = true,
      exclude_buftypes = { "nofile", "prompt", "quickfix", "terminal" },
    },
    keys = {
      {
        "<leader>uC",
        function()
          require("nvim-highlight-colors").toggle()
        end,
        desc = "Toggle color highlights",
      },
    },
  },
}

