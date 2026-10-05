-- ============================================================================
-- plugins/ui-discovery.lua — Keymap Discovery & Discoverability Domain
--
-- Responsibility:
--   • Keymap discovery surface (which-key.nvim)
--   • Leader prefix group documentation
--
-- Non-responsibility:
--   • Functional keymap bindings (owned by respective capability domains)
--
-- Neovim >= 0.12
-- ============================================================================

return {
  -- ========================================================================
  -- which-key.nvim — Keymap Discovery
  -- ========================================================================
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      delay = function(ctx)
        return ctx.plugin and 0 or 300
      end,
      filter = function(m)
        return m.desc and m.desc ~= ""
      end,
      notify = false,
      triggers = { { "<auto>", mode = "nxsot" } },
      defer = function(ctx)
        return ctx.mode == "V" or ctx.mode == "<C-V>"
      end,
      win = {
        border = "rounded",
        padding = { 1, 2 },
        title = true,
        title_pos = "center",
        zindex = 1000,
        wo = { winblend = 0 },
      },
      layout = { width = { min = 20 }, spacing = 3 },
      icons = { breadcrumb = "»", separator = "➜", group = "+", ellipsis = "…", mappings = true },
      spec = {
        { "<leader><tab>", group = "Tabs" },
        { "<leader>b", group = "Buffer" },
        { "<leader>c", group = "Code" },
        { "<leader>cl", group = "LSP Management", icon = " " },
        { "<leader>f", group = "Find/File" },
        { "<leader>g", group = "Git" },
        { "<leader>h", group = "Harpoon" },
        { "<leader>l", group = "LSP" },
        { "<leader>p", group = "Packages", icon = " " },
        { "<leader>pp", group = "Python Packages", icon = " " },
        { "<leader>pr", group = "Rust Crates", icon = " " },
        { "<leader>q", group = "Quit" },
        { "<leader>r", group = "REST/Run" },
        { "<leader>s", group = "Search" },
        { "<leader>t", group = "Terminal" },
        { "<leader>u", group = "UI Toggle" },
        { "<leader>w", group = "Window" },
        { "<leader>x", group = "Trouble" },
      },
    },
  },
}
