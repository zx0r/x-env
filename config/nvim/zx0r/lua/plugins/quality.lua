-- ============================================================================
-- plugins/quality.lua — Code Quality Domain
-- ============================================================================
--
-- Responsibility:
--   Static analysis and code-quality tooling.
--
-- Intended plugins:
--   • Linters
--   • Static analysis helpers
--   • Code metrics
--
-- Boundary:
--   This module owns quality evaluation and static linting.
--
-- Does NOT own:
--   • Formatting                  → coding.lua
--   • LSP servers / Mason         → language.lua
--   • Test runners                → testing.lua
--   • Git / VCS                   → vcs.lua
-- ============================================================================

return {
  -- ==========================================================================
  -- LINTING
  -- ==========================================================================

  {
    "mfussenegger/nvim-lint",

    event = "BufWritePost",

    config = function()
      local lint = require("lint")

      lint.linters_by_ft = {
        python = { "ruff" },

        javascript = { "eslint_d" },
        typescript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        typescriptreact = { "eslint_d" },

        lua = { "selene", "luacheck" },

        sh = { "shellcheck" },
        bash = { "shellcheck" },

        dockerfile = { "hadolint" },

        terraform = { "tflint" },

        markdown = { "markdownlint" },
        yaml = { "yamllint" },

        nix = { "nix" },

        go = { "golangcilint" },

        proto = { "buf_lint" },
        ["*"] = { "typos" },
      }

      lint.linters.selene = vim.tbl_deep_extend("force", lint.linters.selene or {}, {
        condition = function(ctx)
          local path = ctx and ctx.filename or vim.api.nvim_buf_get_name(0)
          return vim.fs.find({ "selene.toml" }, { path = path, upward = true })[1] ~= nil
        end,
      })

      local group = vim.api.nvim_create_augroup(
        "coding_lint",
        { clear = true }
      )

      local function lint_buffer(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) then
          return
        end

        if vim.bo[bufnr].buftype ~= "" then
          return
        end

        if vim.b[bufnr].large_file then
          return
        end

        if vim.b[bufnr].lint_disable then
          return
        end

        local ft = vim.bo[bufnr].filetype
        local names = vim.list_extend({}, lint.linters_by_ft[ft] or {})
        if lint.linters_by_ft["*"] then
          vim.list_extend(names, lint.linters_by_ft["*"])
        end
        if #names == 0 then
          return
        end

        local active = {}
        local ctx = { filename = vim.api.nvim_buf_get_name(bufnr) }
        for _, name in ipairs(names) do
          local linter = lint.linters[name]
          local cmd = (type(linter) == "table" and linter.cmd) or name
          local cond = (type(linter) == "table" and linter.condition)
          local allowed = true
          if cond and type(cond) == "function" then
            allowed = cond(ctx)
          end
          if allowed and vim.fn.executable(cmd) == 1 then
            table.insert(active, name)
          end
        end

        if #active > 0 then
          lint.try_lint(active, {
            cwd = vim.fn.expand("%:p:h"),
            ignore_errors = true,
          })
        end
      end

      vim.api.nvim_create_autocmd(
        "BufWritePost",
        {
          group = group,
          callback = function(args)
            lint_buffer(args.buf)
          end,
        }
      )
    end,
  },

}
