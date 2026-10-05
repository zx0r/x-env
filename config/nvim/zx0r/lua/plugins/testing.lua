-- ============================================================================
-- plugins/testing.lua — Testing Domain
-- ============================================================================
--
-- Responsibility:
--   Test discovery, execution, debugging and test-result presentation.
--
-- Intended plugins:
--   • Test runners
--   • Neotest
--   • Coverage
--   • Test result UI
--   • Test debugging integration
--
-- Boundary:
--   This module owns the testing workflow.
--
-- Does NOT own:
--   • Debugger infrastructure       → debug.lua
--   • LSP configuration             → language.lua
--   • Static analysis / formatting  → quality.lua
-- ============================================================================

return {
  {
    "nvim-neotest/neotest",
    cmd = "Neotest",
    keys = {
      { "<leader>tt", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run file" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle summary" },
    },
    dependencies = {
      "nvim-neotest/nvim-nio",
      -- Enable adapters as needed:
      -- "nvim-neotest/neotest-python",
      -- "nvim-neotest/neotest-go",
      -- "rouge8/neotest-rust",
      -- "marilari88/neotest-vitest",
    },
    opts = function()
      return {
        adapters = {
          -- require("neotest-python"),
          -- require("neotest-go"),
        },
      }
    end,
  },
}
