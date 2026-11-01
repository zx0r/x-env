-- ============================================================================
-- core/audit/init.lua — Unified Audit, Diagnostic & SLA Router
-- Principle: Zero-Overhead command routing with on-demand deferred loading
-- ============================================================================

local M = {}

--- Lazy module accessors
function M.doctor()
  return require("core.audit.doctor")
end

function M.benchmark()
  return require("core.audit.benchmark")
end

function M.antipatterns()
  return require("core.audit.antipatterns")
end

--- Register all diagnostic and audit commands with zero startup cost
function M.setup()
  -- :CoreAudit / :CoreAntiPatterns — Run complete Tree-sitter AST anti-pattern inspection
  local function run_antipatterns(opts)
    local args = {}
    if opts.args and opts.args:match("%-%-json") then args.json = true end
    if opts.args and opts.args:match("%-%-verbose") then args.verbose = true end
    require("core.audit.antipatterns").run(args)
  end
  vim.api.nvim_create_user_command("CoreAudit", run_antipatterns, { nargs = "*", desc = "Run Tree-sitter AST anti-pattern auditor" })
  vim.api.nvim_create_user_command("CoreAntiPatterns", run_antipatterns, { nargs = "*", desc = "Run Tree-sitter AST anti-pattern auditor" })

  -- :CoreDoctor — Run complete architectural invariant & SLA audit
  vim.api.nvim_create_user_command("CoreDoctor", function(opts)
    require("core.audit.doctor").run(opts)
  end, { desc = "Run system invariant and SLA doctor" })

  -- :CoreBenchmark — Run startup latency benchmark (hyperfine)
  vim.api.nvim_create_user_command("CoreBenchmark", function(opts)
    local args = {}
    if opts.args and opts.args ~= "" then
      local runs = tonumber(opts.args)
      if runs then args.runs = runs end
    end
    require("core.audit.benchmark").run(args)
  end, { nargs = "?", desc = "Run cold-start latency benchmark" })

  -- :CoreProfile — Run --startuptime breakdown
  vim.api.nvim_create_user_command("CoreProfile", function()
    require("core.audit.benchmark").profile()
  end, { desc = "Run startup profile and breakdown" })

  -- :CoreLatency — Synthetic runtime performance test (UI frame render + AST parse)
  vim.api.nvim_create_user_command("CoreLatency", function()
    require("core.audit.benchmark").latency()
  end, { desc = "Run synthetic runtime latency tests (UI & AST)" })

  -- :CoreSyncCheck — Scan codebase for synchronous shell calls
  vim.api.nvim_create_user_command("CoreSyncCheck", function()
    require("core.audit.doctor").audit_sync_calls(function(res)
      if res.pass then
        vim.notify("✓ Zero synchronous shell calls detected in lua/ code", vim.log.levels.INFO, { title = "audit/sync" })
      else
        vim.notify("✗ Synchronous shell calls detected:\n" .. table.concat(res.details, "\n"), vim.log.levels.ERROR, { title = "audit/sync" })
      end
    end)
  end, { desc = "Scan codebase for synchronous shell calls" })

  -- :SecOpsScan — Scan buffer for leaked secrets
  vim.api.nvim_create_user_command("SecOpsScan", function()
    require("core.audit.doctor").scan_secrets(nil)
  end, { desc = "Scan current buffer for leaked credentials and tokens" })
end

return M
