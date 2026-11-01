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
    cmd = { "Neotest" },
    keys = {
      {
        "<leader>tt",
        function()
          require("neotest").run.run()
        end,
        desc = "Run nearest test",
      },
      {
        "<leader>tf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run current file",
      },
      {
        "<leader>ts",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Toggle test summary",
      },
      {
        "<leader>to",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Toggle output panel",
      },
      {
        "<leader>tO",
        function()
          require("neotest").output.open({ enter = true, auto_close = true })
        end,
        desc = "Show test output (float)",
      },
      {
        "<leader>tS",
        function()
          require("neotest").run.stop()
        end,
        desc = "Stop running test",
      },
      {
        "<leader>tw",
        function()
          require("neotest").watch.toggle(vim.fn.expand("%"))
        end,
        desc = "Toggle watch test",
      },
      {
        "<leader>td",
        function()
          require("neotest").run.run({ strategy = "dap" })
        end,
        desc = "Debug nearest test (DAP)",
      },
    },
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
      { "nvim-neotest/nvim-nio", lazy = true },
      { "nvim-treesitter/nvim-treesitter", lazy = true },
      { "nvim-neotest/neotest-python", lazy = true },
      { "nvim-neotest/neotest-go", lazy = true },
      { "marilari88/neotest-vitest", lazy = true },
      { "nvim-neotest/neotest-jest", lazy = true },
      { "rcasia/neotest-bash", lazy = true },
    },
    opts = function()
      local adapters = {}

      -- ── Bash / Bats ──
      local ok_bash, neotest_bash = pcall(require, "neotest-bash")
      if ok_bash then
        table.insert(adapters, neotest_bash({}))
      end

      -- ── Python (pytest / unittest) ──
      local ok_py, neotest_python = pcall(require, "neotest-python")
      if ok_py then
        table.insert(
          adapters,
          neotest_python({
            dap = { justMyCode = false },
          })
        )
      end

      -- ── Go (go test) ──
      local ok_go, neotest_go = pcall(require, "neotest-go")
      if ok_go then
        table.insert(
          adapters,
          neotest_go({
            experimental = { test_table = true },
            args = { "-count=1", "-timeout=60s" },
          })
        )
      end

      -- ── TypeScript / JavaScript (Vitest) ──
      local ok_vitest, neotest_vitest = pcall(require, "neotest-vitest")
      if ok_vitest then
        table.insert(
          adapters,
          neotest_vitest({
            filter_dir = function(name)
              return name ~= "node_modules"
            end,
          })
        )
      end

      -- ── TypeScript / JavaScript (Jest Fallback) ──
      local ok_jest, neotest_jest = pcall(require, "neotest-jest")
      if ok_jest then
        table.insert(
          adapters,
          neotest_jest({
            jestCommand = "npm test --",
            env = { CI = true },
            cwd = function()
              return vim.fs.root(0, { "package.json", ".git" }) or vim.fn.getcwd()
            end,
          })
        )
      end

      -- ── Rust (Native rustaceanvim integration) ──
      local ok_rust, rust_adapter = pcall(function()
        return require("rustaceanvim.neotest")
      end)
      if ok_rust and rust_adapter then
        table.insert(adapters, rust_adapter)
      end

      return {
        adapters = adapters,
        status = {
          virtual_text = true,
          signs = true,
        },
        output = {
          open_on_run = false,
        },
        quickfix = {
          open = function()
            if package.loaded["trouble"] then
              require("trouble").open({ mode = "quickfix" })
            else
              vim.cmd("copen")
            end
          end,
        },
        floating = {
          border = "rounded",
          max_height = 0.8,
          max_width = 0.8,
        },
        summary = {
          open = "botright vsplit | vertical resize 45",
        },
      }
    end,
    config = function(_, opts)
      require("neotest").setup(opts)
    end,
  },
}
