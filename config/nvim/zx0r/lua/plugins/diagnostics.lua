-- ============================================================================
-- plugins/diagnostics.lua — Diagnostics Domain
-- ============================================================================
--
-- Responsibility:
--   Diagnostic rendering, signs, virtual text, and orchestration.
--
-- Policy:
--   vim.diagnostic.config() is initialized during plugin init to guarantee
--   policy is active before any buffer opens or LSP attaches.
--
-- Neovim >= 0.12
-- ============================================================================

local function setup_diagnostics()
  vim.diagnostic.config({
    severity_sort = true,
    float = {
      border = "rounded",
      source = "always",
      header = "",
      prefix = " ",
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.HINT] = " ",
        [vim.diagnostic.severity.INFO] = " ",
      },
    },
    virtual_text = {
      spacing = 4,
      source = "if_many",
      prefix = function(diagnostic)
        local icons = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN]  = " ",
          [vim.diagnostic.severity.HINT]  = " ",
          [vim.diagnostic.severity.INFO]  = " ",
        }
        return icons[diagnostic.severity] or " "
      end,
    },
    underline = true,
    update_in_insert = false,
  })

  -- Floating diagnostic widget on line hover (Zero-overhead: only triggers if line has errors)
  local diag_hover_group = vim.api.nvim_create_augroup("core_diagnostics_hover", { clear = true })
  vim.api.nvim_create_autocmd("CursorHold", {
    group = diag_hover_group,
    callback = function()
      if not vim.api.nvim_buf_is_valid(0) or vim.fn.mode() ~= "n" then
        return
      end
      local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
      local diags = vim.diagnostic.get(0, { lnum = lnum })
      if #diags > 0 then
        vim.diagnostic.open_float(nil, {
          focusable = false,
          close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
          border = "rounded",
          source = "always",
          prefix = " ",
          scope = "line",
        })
      end
    end,
  })
end

return {
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "VeryLazy",
    init = function()
      setup_diagnostics()
    end,
    opts = {
      signs = true,
      sign_priority = 8,
      keywords = {
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE" } },
        TODO = { icon = " ", color = "info" },
        HACK = { icon = " ", color = "warning" },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
        PERF = { icon = "󱃮 ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = "󰋽 ", color = "hint", alt = { "INFO" } },
        TEST = { icon = "󰬛 ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
      gui_style = {
        fg = "NONE",
        bg = "BOLD",
      },
      colors = {
        error = { "DiagnosticError", "ErrorMsg", "#DC2626" },
        warning = { "DiagnosticWarn", "WarningMsg", "#FBBF24" },
        info = { "DiagnosticInfo", "#2563EB" },
        hint = { "DiagnosticHint", "#10B981" },
        default = { "Identifier", "#7C3AED" },
        test = { "Identifier", "#FF00FF" },
      },
      highlight = {
        multiline = true,
        multiline_pattern = "^.",
        multiline_context = 10,
        before = "",
        keyword = "wide",
        after = "fg",
      },
    },
    keys = {
      {
        "]t",
        function()
          require("todo-comments").jump_next()
        end,
        desc = "Next todo comment",
      },
      {
        "[t",
        function()
          require("todo-comments").jump_prev()
        end,
        desc = "Previous todo comment",
      },
      {
        "<leader>ft",
        function()
          Snacks.picker.todo_comments()
        end,
        desc = "Find TODOs",
      },
    },
  },
}
