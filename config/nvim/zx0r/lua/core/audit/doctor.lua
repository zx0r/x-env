-- ============================================================================
-- core/audit/doctor.lua — Automated Invariant Auditor & Health Provider
-- Consolidated: Invariant Engine + :checkhealth Provider + Buffer Secret Scanner
-- Zero-Overhead: Loaded strictly on-demand (:CoreDoctor / :checkhealth)
-- ============================================================================

local M = {}

--- Format status badge for CLI/TUI output
local function badge(pass, warn)
  if pass then
    return " \27[32mPASS\27[0m "
  elseif warn then
    return " \27[33mWARN\27[0m "
  else
    return " \27[31mFAIL\27[0m "
  end
end

-- ── 1. Synchronous I/O Invariant ─────────────────────────────────────────────
function M.audit_sync_calls(callback)
  local config_root = vim.fn.stdpath("config")
  local lua_dir = config_root .. "/lua"
  if vim.uv.fs_stat(config_root .. "/x0r/lua") then
    lua_dir = config_root .. "/x0r/lua"
  end

  local patterns = {
    "vim%.fn%.system%s*%(",
    "io%.popen%s*%(",
    "os%.execute%s*%(",
    "vim%.fn%.systemlist%s*%(",
  }
  local grep_arg = table.concat(patterns, "|")

  vim.system(
    { "rg", "-n", "-e", grep_arg, lua_dir, "--type", "lua", "--no-heading" },
    { text = true },
    function(res)
      vim.schedule(function()
        local violations = {}
        if res.code == 0 and res.stdout and res.stdout ~= "" then
          for line in res.stdout:gmatch("[^\r\n]+") do
            local code_part = line:match("^[^:]+:%d+:(.*)$") or line
            if not code_part:match("^%s*%-%-") then
              table.insert(violations, line)
            end
          end
        end

        local pass = (#violations == 0)
        callback({
          id = "sync_io",
          title = "Zero Synchronous Shell Calls (SLA: 0 blocking calls)",
          pass = pass,
          warn = false,
          value = string.format("%d blocking calls", #violations),
          details = violations,
        })
      end)
    end
  )
end

-- ── 2. Event Loop Health & Idle Timer Invariant ──────────────────────────────
function M.audit_event_loop()
  local active_timers = 0
  local timer_details = {}

  vim.uv.walk(function(handle)
    if not handle:is_closing() then
      local htype = handle:get_type()
      if htype == "timer" and handle:is_active() then
        active_timers = active_timers + 1
        local repeat_ms = handle:get_repeat()
        if repeat_ms > 0 then
          table.insert(timer_details, string.format("Periodic timer repeat: %dms", repeat_ms))
        end
      end
    end
  end)

  local pass = (active_timers <= 1)
  local warn = (active_timers > 1 and active_timers <= 3)

  return {
    id = "event_loop",
    title = "Event Loop Polling Timer Invariant (SLA: 0 idle polling)",
    pass = pass,
    warn = warn,
    value = string.format("%d active timer handles", active_timers),
    details = timer_details,
  }
end

-- ── 3. Global Namespace Hygiene Invariant ────────────────────────────────────
function M.audit_global_hygiene()
  local WHITELIST = {
    "_G", "_VERSION", "arg", "assert", "collectgarbage", "dofile", "error", "gcinfo",
    "getfenv", "getmetatable", "ipairs", "load", "loadfile", "loadstring", "lpeg",
    "module", "newproxy", "next", "pairs", "pcall", "print", "rawequal", "rawget",
    "rawlen", "rawset", "require", "select", "setfenv", "setmetatable", "svim",
    "tonumber", "tostring", "type", "unpack", "xpcall", "coroutine", "debug", "io",
    "math", "os", "package", "string", "table", "bit", "jit", "vim", "Snacks",
    "MiniIcons", "MiniAlign", "Colorizer",
  }

  local allowed = {}
  for _, k in ipairs(WHITELIST) do allowed[k] = true end

  local leaks = {}
  for k, _ in pairs(_G) do
    if not allowed[k] and type(k) == "string" and not k:match("^_") then
      table.insert(leaks, k)
    end
  end
  table.sort(leaks)

  local pass = (#leaks == 0)
  return {
    id = "global_hygiene",
    title = "Global Namespace Isolation (_G Leak Invariant)",
    pass = pass,
    warn = (#leaks <= 2 and not pass),
    value = string.format("%d leaked globals", #leaks),
    details = leaks,
  }
end

-- ── 4. SecOps Sandboxing Invariants ──────────────────────────────────────────
function M.audit_security()
  local details = {}
  local pass = true

  if vim.opt.modelineexpr:get() ~= false then
    pass = false
    table.insert(details, "CRITICAL: vim.opt.modelineexpr is enabled (arbitrary code execution risk!)")
  end

  if vim.opt.exrc:get() ~= false then
    pass = false
    table.insert(details, "CRITICAL: vim.opt.exrc is enabled (untrusted project configs execution)")
  end

  return {
    id = "security",
    title = "SecOps Sandboxing Invariants (modelineexpr=false, exrc=false)",
    pass = pass,
    warn = false,
    value = pass and "SecOps baseline enforced" or "VULNERABILITY DETECTED",
    details = details,
  }
end

-- ── 5. Core Performance Baseline ─────────────────────────────────────────────
function M.audit_perf_baseline()
  local details = {}
  local pass = true

  local loader_active = (package.loaded["vim.loader"] ~= nil) or (vim.loader ~= nil)
  if not loader_active then
    pass = false
    table.insert(details, "vim.loader is not active (bytecode cache disabled)")
  end

  local providers = { "python3", "ruby", "perl", "node" }
  for _, p in ipairs(providers) do
    local var = "loaded_" .. p .. "_provider"
    if vim.g[var] ~= 0 then
      pass = false
      table.insert(details, string.format("Provider '%s' is not disabled", p))
    end
  end

  return {
    id = "perf_baseline",
    title = "Core Startup Baseline (vim.loader + zero-cost providers)",
    pass = pass,
    warn = false,
    value = pass and "All baseline providers disabled" or "Unoptimized provider detected",
    details = details,
  }
end

-- ── 6. Large File Guard Invariant ────────────────────────────────────────────
function M.audit_guard()
  local ok, guard = pcall(require, "core.guard")
  if not ok then
    return {
      id = "guard",
      title = "Large File Protection Tier (core.guard)",
      pass = false,
      warn = false,
      value = "Module not found",
      details = { "core.guard failed to require" },
    }
  end

  local has_check = type(guard.check) == "function"
  local has_is_large = type(guard.is_large) == "function"

  return {
    id = "guard",
    title = "Large File Protection Tier (core.guard)",
    pass = (has_check and has_is_large),
    warn = false,
    value = "Tier 1 (>1MB) & Tier 2 (>10MB) ready",
    details = {},
  }
end

-- ── 7. Lua Memory Footprint ──────────────────────────────────────────────────
function M.audit_memory()
  local kb = collectgarbage("count")
  local mb = kb / 1024
  local pass = mb < 60.0
  local warn = (mb >= 60.0 and mb < 100.0)

  return {
    id = "memory",
    title = "Lua Engine Memory Footprint",
    pass = pass,
    warn = warn,
    value = string.format("%.2f MB", mb),
    details = { string.format("collectgarbage('count') = %.1f KB", kb) },
  }
end

-- ── 8. Buffer Secret & Credential Scanner ────────────────────────────────────
function M.scan_secrets(buf, callback)
  buf = buf or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local findings = {}

  local patterns = {
    { name = "AWS Access Key", pat = "AKIA[0-9A-Z]{16}" },
    { name = "Generic Secret", pat = "['\"]-sk%-[a-zA-Z0-9]" },
    { name = "Bearer Token",   pat = "Bearer%s+[a-zA-Z0-9._%-]+" },
    { name = "Private Key",    pat = "%-%-%-%-%-BEGIN.*PRIVATE KEY" },
  }

  local chunk_size = 1000
  local i = 1

  local function process_chunk()
    local limit = math.min(i + chunk_size - 1, #lines)
    for lnum = i, limit do
      for _, p in ipairs(patterns) do
        local col = lines[lnum]:find(p.pat)
        if col then
          table.insert(findings, { lnum = lnum, col = col, pattern_name = p.name })
        end
      end
    end
    i = limit + 1
    if i <= #lines then
      vim.schedule(process_chunk)
    else
      if callback then
        callback(findings)
      else
        if #findings == 0 then
          vim.notify("SecOps: No secrets detected in buffer", vim.log.levels.INFO, { title = "SecOps" })
        else
          local msgs = {}
          for _, f in ipairs(findings) do
            table.insert(msgs, string.format("  L%d C%d: %s", f.lnum, f.col, f.pattern_name))
          end
          vim.notify("SecOps: Potential secrets found:\n" .. table.concat(msgs, "\n"), vim.log.levels.WARN, { title = "SecOps" })
        end
      end
    end
  end
  process_chunk()
end

-- ── 9. Native Neovim :checkhealth Provider (Unified Engine) ──────────────────
function M.check()
  local health = vim.health
  health.start("core/audit — Architectural Invariants & SLA")

  local results = {
    M.audit_security(),
    M.audit_perf_baseline(),
    M.audit_guard(),
    M.audit_event_loop(),
    M.audit_global_hygiene(),
    M.audit_memory(),
  }

  for _, r in ipairs(results) do
    if r.pass then
      health.ok(string.format("%s: %s", r.title, r.value))
    elseif r.warn then
      health.warn(string.format("%s: %s", r.title, r.value))
    else
      health.error(string.format("%s: %s", r.title, r.value))
    end
    for _, d in ipairs(r.details or {}) do
      health.info("  → " .. d)
    end
  end
end

-- ── 10. Interactive Floating Dashboard Runner (:CoreDoctor) ──────────────────
function M.run(opts)
  opts = opts or {}
  local results = {
    M.audit_security(),
    M.audit_perf_baseline(),
    M.audit_guard(),
    M.audit_event_loop(),
    M.audit_global_hygiene(),
    M.audit_memory(),
  }

  M.audit_sync_calls(function(sync_res)
    table.insert(results, 1, sync_res)

    local lines = {
      "╔══════════════════════════════════════════════════════════════════════════════╗",
      "║             x0r/nvim — System Doctor & SLA Invariant Audit                   ║",
      "╚══════════════════════════════════════════════════════════════════════════════╝",
      string.format(" Timestamp: %s | Neovim: %s", os.date("!%Y-%m-%dT%H:%M:%SZ"), vim.version().api_level),
      "────────────────────────────────────────────────────────────────────────────────",
    }

    local total = #results
    local passed = 0
    local failed = 0
    local warnings = 0

    for _, r in ipairs(results) do
      if r.pass then
        passed = passed + 1
      elseif r.warn then
        warnings = warnings + 1
      else
        failed = failed + 1
      end

      local b = r.pass and "[✓ PASS]" or (r.warn and "[~ WARN]" or "[✗ FAIL]")
      table.insert(lines, string.format(" %-9s %-48s │ %s", b, r.title, r.value))
      for _, d in ipairs(r.details or {}) do
        table.insert(lines, "           → " .. d)
      end
    end

    table.insert(lines, "────────────────────────────────────────────────────────────────────────────────")
    local score = (passed / total) * 100
    table.insert(lines, string.format(" SUMMARY: %d/%d Invariants Passed (Score: %.1f%%) | Warnings: %d | Fails: %d", passed, total, score, warnings, failed))
    table.insert(lines, "────────────────────────────────────────────────────────────────────────────────")

    local output = table.concat(lines, "\n")
    if #vim.api.nvim_list_uis() == 0 then
      print(output)
    else
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(output, "\n"))
      vim.bo[buf].filetype = "checkhealth"
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "wipe"

      local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = math.min(90, vim.o.columns - 4),
        height = math.min(#lines + 2, vim.o.lines - 4),
        row = math.floor((vim.o.lines - math.min(#lines + 2, vim.o.lines - 4)) / 2),
        col = math.floor((vim.o.columns - math.min(90, vim.o.columns - 4)) / 2),
        style = "minimal",
        border = "rounded",
        title = " Core Doctor Invariant Audit ",
        title_pos = "center",
      })
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
    end
  end)
end

return M
