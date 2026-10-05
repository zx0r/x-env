-- ============================================================================
-- core/audit/benchmark.lua — Latency, Startup & Performance Benchmarking
-- Consolidated: Hyperfine Runner + Startuptime Profile + Synthetic Latency
-- Zero-Overhead: Loaded strictly on-demand (:CoreBenchmark / :CoreProfile)
-- ============================================================================

local M = {}

--- Helper to get isolated XDG environment for subprocess calls
local function get_xdg_env()
  local config_home = vim.fn.stdpath("config")
  local xdg_home = vim.fs.dirname(config_home)
  local app_name = vim.fs.basename(config_home)
  return xdg_home, app_name
end

-- ── 1. Startup Benchmark (Hyperfine) ─────────────────────────────────────────
function M.run(opts)
  opts = opts or {}
  local warmup   = opts.warmup or 3
  local runs     = opts.runs or 10
  local max_runs = opts.max_runs or 20

  local nvim_cmd = vim.v.progpath
  local xdg_home, app_name = get_xdg_env()
  local cmd_str = string.format(
    "env XDG_CONFIG_HOME=%s NVIM_APPNAME=%s %s --headless -c 'qa'",
    vim.fn.shellescape(xdg_home),
    vim.fn.shellescape(app_name),
    vim.fn.shellescape(nvim_cmd)
  )

  vim.notify("Executing cold-start benchmark (" .. runs .. " runs)...", vim.log.levels.INFO, { title = "audit/benchmark" })

  local args = {
    "hyperfine",
    cmd_str,
    "--warmup", tostring(warmup),
    "--runs",   tostring(runs),
    "--max-runs", tostring(max_runs),
    "--export-json", "/tmp/core_bench.json",
  }

  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify(
          "hyperfine failed:\n" .. (result.stderr or "unknown error"),
          vim.log.levels.ERROR,
          { title = "audit/benchmark" }
        )
        return
      end

      local json_ok, json_data = pcall(function()
        local f = io.open("/tmp/core_bench.json", "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        return vim.json.decode(content)
      end)

      if json_ok and json_data and json_data.results and json_data.results[1] then
        local r = json_data.results[1]
        local mean_ms   = (r.mean or 0) * 1000
        local stddev_ms = (r.stddev or 0) * 1000
        local min_ms    = (r.min or 0) * 1000
        local max_ms    = (r.max or 0) * 1000

        local sla_ok   = mean_ms < 20.0
        local sla_icon = sla_ok and "[✓ PASS]" or "[✗ FAIL]"
        local level    = sla_ok and vim.log.levels.INFO or vim.log.levels.ERROR

        local report = string.format(
          table.concat({
            "┌────────────────────────────────────────────────────────┐",
            "│          Core System — Cold Startup Benchmark          │",
            "├────────────────────────────────────────────────────────┤",
            "│  Mean Latency:    %6.2f ms   (SLA: <20.0ms %s)    │",
            "│  Std Deviation:   %6.2f ms                             │",
            "│  Min Latency:     %6.2f ms                             │",
            "│  Max Latency:     %6.2f ms                             │",
            "│  Completed Runs:  %-6d                               │",
            "├────────────────────────────────────────────────────────┤",
            "│  Data Exported:   /tmp/core_bench.json                 │",
            "└────────────────────────────────────────────────────────┘",
          }, "\n"),
          mean_ms, sla_icon,
          stddev_ms,
          min_ms,
          max_ms,
          r.times and #r.times or runs
        )

        vim.notify(report, level, { title = "audit/benchmark", timeout = 12000 })
      else
        vim.notify(result.stdout or "No output", vim.log.levels.INFO, { title = "audit/benchmark" })
      end
    end)
  end)
end

-- ── 2. Startup Timeline Profile (--startuptime breakdown) ────────────────────
function M.profile()
  local nvim_cmd = vim.v.progpath
  local log_path = "/tmp/core_startuptime.log"
  local xdg_home, app_name = get_xdg_env()

  vim.system(
    { nvim_cmd, "--startuptime", log_path, "--headless", "-c", "qa" },
    {
      text = true,
      env = {
        XDG_CONFIG_HOME = xdg_home,
        NVIM_APPNAME = app_name,
        PATH = vim.env.PATH,
        HOME = vim.env.HOME,
      },
    },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify("startuptime capture failed: " .. (result.stderr or ""), vim.log.levels.ERROR, { title = "audit/profile" })
        return
      end

      local entries = {}
      local f = io.open(log_path, "r")
      if f then
        for line in f:lines() do
          local elapsed, _, event = line:match("^%s*(%d+%.%d+)%s+(%d+%.%d+): (.+)")
          if elapsed and event then
            table.insert(entries, { elapsed = tonumber(elapsed), event = event })
          end
        end
        f:close()
      end

      local lines = {
        "┌────────────────────────────────────────────────────────┐",
        "│              Core System — Startup Profile             │",
        "├────────────┬───────────────────────────────────────────┤",
        "│  Time (ms) │  Lifecycle Event                          │",
        "├────────────┼───────────────────────────────────────────┤",
      }

      table.sort(entries, function(a, b) return a.elapsed > b.elapsed end)
      for i = 1, math.min(20, #entries) do
        local e = entries[i]
        table.insert(lines, string.format("│  %8.3f  │  %-41.41s│", e.elapsed, e.event))
      end

      if #entries > 0 then
        local total = entries[1].elapsed
        table.insert(lines, "├────────────┼───────────────────────────────────────────┤")
        table.insert(lines, string.format("│  %8.3f  │  TOTAL STARTUP LATENCY                    │", total))
        local sla = total < 20.0 and "✓ PASS" or "✗ EXCEEDED"
        table.insert(lines, string.format("│            │  SLA (<20.0ms): %-25s │", sla))
      end

      table.insert(lines, "└────────────┴───────────────────────────────────────────┘")
      vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "audit/profile", timeout = 15000 })
    end)
  )
end

-- ── 3. Synthetic Latency Test (UI Frame & Treesitter AST) ────────────────────
function M.latency()
  local lines = {
    "┌────────────────────────────────────────────────────────┐",
    "│             Core System — Synthetic Latency            │",
    "├─────────────┬──────────────────────────────────────────┤",
  }

  -- UI Frame Rendering (100 frame redraw burst)
  local ui_start = vim.uv.hrtime()
  for _ = 1, 100 do
    vim.cmd("redraw")
  end
  local ui_end = vim.uv.hrtime()
  local ui_frame_ms = ((ui_end - ui_start) / 1e6) / 100
  local ui_icon = ui_frame_ms <= 2.0 and "✓" or "✗"
  table.insert(lines, string.format("│ %s UI Frame │ Redraw Latency:            %6.2f ms       │", ui_icon, ui_frame_ms))

  -- Treesitter Incremental AST Parse
  local ts_start = vim.uv.hrtime()
  local ts_ok, parser = pcall(vim.treesitter.get_parser, 0)
  if ts_ok and parser then
    parser:parse()
    local ts_end = vim.uv.hrtime()
    local ts_ms = (ts_end - ts_start) / 1e6
    local ts_icon = ts_ms <= 5.0 and "✓" or "✗"
    table.insert(lines, string.format("│ %s AST Parse│ Incremental Parse Latency: %6.2f ms       │", ts_icon, ts_ms))
  else
    table.insert(lines, "│ - AST Parse│ Incremental Parse Latency:    N/A         │")
  end

  table.insert(lines, "└─────────────┴──────────────────────────────────────────┘")
  local report = table.concat(lines, "\n")
  if #vim.api.nvim_list_uis() == 0 then
    print(report)
  else
    vim.notify(report, vim.log.levels.INFO, { title = "audit/latency" })
  end
end

return M
