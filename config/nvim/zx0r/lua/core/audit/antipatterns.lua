-- ============================================================================
-- core/audit/antipatterns.lua — Industrial AST & Runtime Invariant Auditor
-- Standard: Capability-Oriented Domain Architecture (CODA) & Zero-Overhead SLA
-- Engine: Native Neovim 0.12+ (LuaJIT 2.1 + Tree-sitter C-Parser + LibUV)
-- Principle: Self-contained, zero external dependencies, on-demand execution
-- ============================================================================

local uv = vim.uv or vim.loop
local M = {}

-- ── ANSI Terminal Formatter ──────────────────────────────────────────────────
local C = {
  reset   = "\27[0m",
  bold    = "\27[1m",
  dim     = "\27[2m",
  red     = "\27[31m",
  green   = "\27[32m",
  yellow  = "\27[33m",
  blue    = "\27[34m",
  magenta = "\27[35m",
  cyan    = "\27[36m",
  white   = "\27[37m",
  gray    = "\27[90m",
}

-- ── Path Context Resolution ──────────────────────────────────────────────────
local function resolve_paths()
  local config_path = vim.fn.stdpath("config")
  local repo_root
  if config_path and uv.fs_stat(config_path) then
    repo_root = config_path
  else
    local src = debug.getinfo(1, "S").source:sub(2)
    local real = uv.fs_realpath(src)
    if real then
      repo_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(real))))
    else
      repo_root = uv.cwd()
    end
  end

  local lua_dir = vim.fs.joinpath(repo_root, "lua")
  if not uv.fs_stat(lua_dir) and uv.fs_stat(vim.fs.joinpath(repo_root, "zx0r", "lua")) then
    repo_root = vim.fs.joinpath(repo_root, "zx0r")
    lua_dir = vim.fs.joinpath(repo_root, "lua")
  end

  return {
    repo_root   = repo_root,
    lua_dir     = lua_dir,
    core_dir    = vim.fs.joinpath(lua_dir, "core"),
    plugins_dir = vim.fs.joinpath(lua_dir, "plugins"),
    init_file   = vim.fs.joinpath(repo_root, "init.lua"),
  }
end

-- ── File Reading & Tree-sitter Utilities ─────────────────────────────────────
local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then return nil end
  local stat = uv.fs_fstat(fd)
  if not stat then uv.fs_close(fd); return nil end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data
end

local function scandir_recursive(dir, ext)
  local files = {}
  local function walk(current)
    local handle = uv.fs_scandir(current)
    if not handle then return end
    while true do
      local name, type = uv.fs_scandir_next(handle)
      if not name then break end
      local full = vim.fs.joinpath(current, name)
      if type == "directory" then
        walk(full)
      elseif type == "file" then
        if not ext or full:sub(-#ext) == ext then
          table.insert(files, full)
        end
      end
    end
  end
  walk(dir)
  return files
end

local function get_tree_root(code)
  local ok, parser = pcall(vim.treesitter.get_string_parser, code, "lua")
  if not ok or not parser then return nil end
  local ok_parse, tree = pcall(function() return parser:parse()[1] end)
  if not ok_parse or not tree then return nil end
  return tree:root()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INVARIANT AUDIT ENGINE (AP-01 to AP-28)
-- ═══════════════════════════════════════════════════════════════════════════

function M.scan_all()
  local P = resolve_paths()
  local findings = {}
  local total_rules = 0
  local passed_count = 0

  local function add_finding(code, severity, title, file, line, snippet, impact, remediation)
    local rel_file = file
    if rel_file:sub(1, #P.repo_root) == P.repo_root then
      rel_file = rel_file:sub(#P.repo_root + 2)
    end
    table.insert(findings, {
      code = code,
      severity = severity,
      title = title,
      file = rel_file,
      line = line or 1,
      snippet = snippet or "",
      impact = impact or "",
      remediation = remediation or "",
    })
  end

  local function pass_rule()
    passed_count = passed_count + 1
  end

  local t0 = uv.hrtime()

  -- ── AP-01: vim.loader.enable() at Bytecode Bootstrap Entrypoint ───────────
  total_rules = total_rules + 1
  local init_content = read_file(P.init_file)
  if not init_content then
    add_finding("AP-01", "CRITICAL", "init.lua missing or unreadable", "init.lua", 1, "", "Loader check failed", "Create init.lua")
  else
    local clean = init_content:gsub("%-%-[^\n]*", "")
    if not clean:match("vim%.loader%.enable%s*%(%s*%)") then
      add_finding("AP-01", "CRITICAL", "vim.loader.enable() missing from init.lua", "init.lua", 1, "<missing>", "+15-20ms cold-boot latency penalty.", "Call vim.loader.enable() as the very first executable statement in init.lua.")
    else
      pass_rule()
    end
  end

  -- ── AP-02: Legacy Remote Providers Suppression ────────────────────────────
  total_rules = total_rules + 1
  local perf_file = vim.fs.joinpath(P.core_dir, "perf.lua")
  local perf_content = read_file(perf_file) or ""
  local providers = { "python3", "ruby", "perl", "node" }
  local missing_prov = {}
  for _, p in ipairs(providers) do
    if not perf_content:match("loaded_" .. p .. "_provider%s*=%s*0") then
      table.insert(missing_prov, p)
    end
  end
  if #missing_prov > 0 then
    add_finding("AP-02", "HIGH", "Legacy remote providers not suppressed: " .. table.concat(missing_prov, ", "), "lua/core/perf.lua", 1, "", "Synchronous PATH resolution delays startup by 5-15ms.", "Set loaded_<provider>_provider = 0 in core/perf.lua.")
  else
    pass_rule()
  end

  -- ── AP-03: Zero Synchronous Shell Calls in Hot Paths ──────────────────────
  total_rules = total_rules + 1
  local sync_violations = {}
  local lua_files = scandir_recursive(P.lua_dir, ".lua")
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        local clean = line:match("^%s*(.-)%s*$")
        if clean and not clean:match("^%-%-") then
          if clean:match("vim%.fn%.system%s*%(")
             or clean:match("io%.popen%s*%(")
             or clean:match("os%.execute%s*%(")
             or clean:match("vim%.fn%.systemlist%s*%(") then
            table.insert(sync_violations, { file = f, line = i, snippet = clean })
          end
        end
      end
    end
  end
  if #sync_violations > 0 then
    for _, v in ipairs(sync_violations) do
      add_finding("AP-03", "CRITICAL", "Synchronous shell I/O call detected in hot path", v.file, v.line, v.snippet, "Blocks Neovim main thread event loop; causes visible UI frame stutter.", "Migrate to non-blocking vim.system({ ... }, { text = true }, callback) or LibUV.")
    end
  else
    pass_rule()
  end

  -- ── AP-04: Zero Repeating LibUV Idle Polling Timers ───────────────────────
  total_rules = total_rules + 1
  local repeating_found = false
  if uv.walk then
    uv.walk(function(handle)
      if handle and not handle:is_closing() and handle:get_type() == "timer" and handle:is_active() then
        if handle.get_repeat and handle:get_repeat() > 0 then
          repeating_found = true
        end
      end
    end)
  end
  if repeating_found then
    add_finding("AP-04", "CRITICAL", "Active repeating LibUV timer handle detected", "event_loop", 1, "", "Prevents deep CPU sleep; causes battery drain and context-switch overhead.", "Replace recurring timer polling with native event autocommands.")
  else
    pass_rule()
  end

  -- ── AP-05: Global _G Namespace Isolation ──────────────────────────────────
  total_rules = total_rules + 1
  local global_violations = {}
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        local clean = line:match("^%s*(.-)%s*$")
        if clean and not clean:match("^%-%-") then
          local m = clean:match("^_G%.([a-zA-Z0-9_]+)%s*=")
          if m and m ~= "Snacks" and m ~= "MiniIcons" and m ~= "Colorizer" and m ~= "ACP" then
            table.insert(global_violations, { file = f, line = i, snippet = clean })
          end
        end
      end
    end
  end
  if #global_violations > 0 then
    for _, v in ipairs(global_violations) do
      add_finding("AP-05", "HIGH", "Unsanctioned _G global assignment detected", v.file, v.line, v.snippet, "Pollutes global namespace; causes cross-domain state corruption.", "Encapsulate symbols inside local module tables (local M = {}).")
    end
  else
    pass_rule()
  end

  -- ── AP-06: Headless Theme Compilation Deferral ────────────────────────────
  total_rules = total_rules + 1
  if init_content and not init_content:match("nvim_list_uis") and not init_content:match("UIEnter") then
    add_finding("AP-06", "MEDIUM", "Headless theme compilation deferral missing in init.lua", "init.lua", 1, "", "Wastes highlight compilation time in headless CI benchmarks.", "Wrap initial theme application in: if #vim.api.nvim_list_uis() > 0 then ... end")
  else
    pass_rule()
  end

  -- ── AP-07: Zero Legacy ':syntax reset' Overhead ───────────────────────────
  total_rules = total_rules + 1
  local theme_file = vim.fs.joinpath(P.repo_root, "lua", "theme", "master.lua")
  local theme_content = read_file(theme_file) or ""
  if theme_content:match("vim%.cmd%s*%(?%s*['\"]syntax%s+reset['\"]") then
    add_finding("AP-07", "HIGH", "Legacy ':syntax reset' detected in theme engine", "lua/theme/master.lua", 1, "", "+5-8ms startup penalty from reloading syncolor.vim.", "Remove ':syntax reset'; rely strictly on vim.api.nvim_set_hl().")
  else
    pass_rule()
  end

  -- ── AP-08: lazy.nvim Missing Plugins Determinism ──────────────────────────
  total_rules = total_rules + 1
  local lazy_file = vim.fs.joinpath(P.core_dir, "lazy.lua")
  local lazy_content = read_file(lazy_file) or ""
  if lazy_content:match("missing%s*=%s*true") then
    add_finding("AP-08", "MEDIUM", "lazy.nvim 'install.missing = true' active", "lua/core/lazy.lua", 1, "", "+8-10ms cold start overhead from UI view loading.", "Set install = { missing = false } in deterministic production environments.")
  else
    pass_rule()
  end

  -- ── AP-12 (Tree-sitter AST): Indent-0 Mutating API Calls in plugins/*.lua ─
  total_rules = total_rules + 1
  local ap12_violations = {}
  local plugin_files = scandir_recursive(P.plugins_dir, ".lua")
  local ap12_query = [[ (chunk (function_call) @call) ]]

  for _, f in ipairs(plugin_files) do
    local code = read_file(f) or ""
    local root = get_tree_root(code)
    if root then
      local ok, query = pcall(vim.treesitter.query.parse, "lua", ap12_query)
      if ok and query then
        for id, node in query:iter_captures(root, code) do
          local text = vim.treesitter.get_node_text(node, code)
          local s_row, s_col = node:start()
          if s_col == 0 and not text:match("^%-%-") then
            if text:match("^vim%.api%.nvim_create_autocmd")
               or text:match("^vim%.keymap%.set")
               or text:match("^vim%.cmd")
               or text:match("^vim%.opt%.") then
              table.insert(ap12_violations, {
                file = f,
                line = s_row + 1,
                snippet = vim.split(text, "\n")[1],
              })
            end
          end
        end
      end
    end
  end
  if #ap12_violations > 0 then
    for _, v in ipairs(ap12_violations) do
      add_finding("AP-12", "HIGH", "Top-level mutating API call at module scope (Tree-sitter AST verified)", v.file, v.line, v.snippet, "Executes eagerly during plugin spec discovery; violates Ring 1 zero-overhead.", "Move call inside plugin config callback or core/autocmds.lua.")
    end
  else
    pass_rule()
  end

  -- ── AP-13: Satellite snacks.nvim Lifecycle Hooks Isolation ────────────────
  total_rules = total_rules + 1
  local ap13_violations = {}
  local allowed_owners = { ["ui.lua"] = true, ["ui-messages.lua"] = true, ["ui-notifications.lua"] = true }
  for _, f in ipairs(plugin_files) do
    local fname = vim.fs.basename(f)
    if not allowed_owners[fname] then
      local code = read_file(f) or ""
      if code:match("folke/snacks%.nvim") then
        local lines = vim.split(code, "\n")
        local in_snacks = false
        local depth = 0
        for i, line in ipairs(lines) do
          local clean = line:match("^%s*(.-)%s*$")
          if clean and not clean:match("^%-%-") then
            if clean:match('["\']folke/snacks%.nvim["\']') then
              in_snacks = true
              depth = select(2, clean:gsub("{", "")) - select(2, clean:gsub("}", ""))
            elseif in_snacks then
              depth = depth + select(2, clean:gsub("{", "")) - select(2, clean:gsub("}", ""))
              if clean:match("%f[%w]init%s*=%s*function") or clean:match("%f[%w]config%s*=%s*function") then
                table.insert(ap13_violations, { file = f, line = i, snippet = clean })
              end
              if depth <= 0 then in_snacks = false end
            end
          end
        end
      end
    end
  end
  if #ap13_violations > 0 then
    for _, v in ipairs(ap13_violations) do
      add_finding("AP-13", "HIGH", "Satellite snacks.nvim spec defines lifecycle hook (init/config)", v.file, v.line, v.snippet, "Violates AGENTS.md §5; creates non-deterministic lifecycle overrides in lazy.nvim.", "Satellite specs must supply ONLY declarative opts and keys.")
    end
  else
    pass_rule()
  end

  -- ── AP-14: Zero Eager blink.cmp Attachment on BufReadPre ──────────────────
  total_rules = total_rules + 1
  local coding_file = vim.fs.joinpath(P.plugins_dir, "coding.lua")
  local coding_content = read_file(coding_file) or ""
  if coding_content:match("['\"]Saghen/blink%.cmp['\"].-event%s*=%s*['\"]BufReadPre['\"]") then
    add_finding("AP-14", "CRITICAL", "blink.cmp declared with event = 'BufReadPre'", "lua/plugins/coding.lua", 1, "", "+24.43ms buffer-open latency penalty on Rust FFI compilation.", "Rely strictly on lazy-loading blink.cmp on InsertEnter or key trigger.")
  else
    pass_rule()
  end

  -- ── AP-15: Zero Top-Level require('schemastore') in LSP Manifests ─────────
  total_rules = total_rules + 1
  local ap15_violations = {}
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        local clean = line:match("^%s*(.-)%s*$")
        if clean and not clean:match("^%-%-") then
          if clean:match('require%s*%(?%s*["\']schemastore["\']') and not clean:match("function") then
            table.insert(ap15_violations, { file = f, line = i, snippet = clean })
          end
        end
      end
    end
  end
  if #ap15_violations > 0 then
    for _, v in ipairs(ap15_violations) do
      add_finding("AP-15", "MEDIUM", "Top-level require('schemastore') detected in LSP manifest", v.file, v.line, v.snippet, "Synchronously parses JSON schema catalog (+4.34ms overhead).", "Defer schemastore resolution inside before_init or on_new_config callback.")
    end
  else
    pass_rule()
  end

  -- ── AP-17: Zero Blocking format_on_save ───────────────────────────────────
  total_rules = total_rules + 1
  if coding_content:match("format_on_save%s*=%s*{") and not coding_content:match("format_after_save%s*=%s*{") then
    add_finding("AP-17", "HIGH", "Blocking format_on_save detected in conform.nvim", "lua/plugins/coding.lua", 1, "", "Blocks editor input for up to 3000ms if external formatter stalls.", "Use non-blocking format_after_save = { lsp_format = 'fallback' }.")
  else
    pass_rule()
  end

  -- ── AP-20: Large-File Guard Integrity ─────────────────────────────────────
  total_rules = total_rules + 1
  local autocmds_file = vim.fs.joinpath(P.core_dir, "autocmds.lua")
  local autocmds_content = read_file(autocmds_file) or ""
  local has_bufreadpre = autocmds_content:match("BufReadPre")
  local has_guard_call = autocmds_content:match("core%.guard") and (autocmds_content:match("guard%.check") or autocmds_content:match("guard%.setup"))
  if not (has_bufreadpre and has_guard_call) then
    add_finding("AP-20", "CRITICAL", "Large-file guard bypass: core.guard.check() missing from BufReadPre", "lua/core/autocmds.lua", 1, "", "Files > 1MB crash Neovim with Treesitter AST recursion and LSP OOM.", "Attach core.guard.check(event.buf) on BufReadPre before parser attachment.")
  else
    pass_rule()
  end

  -- ── AP-21: Terminal Cursor Restoration on VimLeave ────────────────────────
  total_rules = total_rules + 1
  local has_vimleave = autocmds_content:match("VimLeave")
  local has_seq = autocmds_content:match("\\27%[3%s*q\\27%]112\\7") or autocmds_content:match("\\x1b%[3%s*q\\x1b%]112")
  local has_ui_guard = autocmds_content:match("nvim_list_uis")
  if not (has_vimleave and has_seq) then
    add_finding("AP-21", "CRITICAL", "Terminal cursor restore sequence missing from VimLeave", "lua/core/autocmds.lua", 1, "", "Terminal cursor trapped in editor block mode or leaks theme accent color.", "Emit io.stdout:write('\\27[3 q\\27]112\\7') inside VimLeave autocommand.")
  elseif not has_ui_guard then
    add_finding("AP-21", "HIGH", "VimLeave terminal cursor restore lacks headless UI guard", "lua/core/autocmds.lua", 1, "", "Contaminates stdout stream during headless CI benchmarks.", "Wrap cursor restore in: if #vim.api.nvim_list_uis() > 0 then ... end")
  else
    pass_rule()
  end

  -- ── AP-22: Zero Synchronous Stream / PTY flush() in Teardown ──────────────
  total_rules = total_rules + 1
  local flush_violations = {}
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        local clean = line:match("^%s*(.-)%s*$")
        if clean and not clean:match("^%-%-") then
          if clean:match("io%.stdout:flush%s*%(") or clean:match("io%.flush%s*%(") then
            table.insert(flush_violations, { file = f, line = i, snippet = clean })
          end
        end
      end
    end
  end
  if #flush_violations > 0 then
    for _, v in ipairs(flush_violations) do
      add_finding("AP-22", "HIGH", "Synchronous stream flush() detected in Lua runtime", v.file, v.line, v.snippet, "Blocks Neovim event loop on PTY write syscall; causes exit micro-stutter.", "Remove flush(); rely on non-blocking io.stdout:write() and standard process exit.")
    end
  else
    pass_rule()
  end

  -- ── AP-23: Canonical guicursor Specification & Blinking Ban ───────────────
  total_rules = total_rules + 1
  local opts_file = vim.fs.joinpath(P.core_dir, "options.lua")
  local opts_content = read_file(opts_file) or ""
  local gc = opts_content:match('guicursor%s*=%s*["\']([^"\']+)["\']')
  if not gc then
    add_finding("AP-23", "HIGH", "vim.opt.guicursor assignment missing from core/options.lua", "lua/core/options.lua", 1, "", "Default cursor configuration allows compositor wakeups.", "Set canonical guicursor with a:blinkon0 in core/options.lua.")
  else
    local issues = {}
    if not gc:match("a:blinkon0") then table.insert(issues, "missing global 'a:blinkon0'") end
    if gc:match("blinkon[1-9]") then table.insert(issues, "contains active cursor blink interval (violates Zero-Overhead SLA)") end
    for _, mode in ipairs({ "n%-v%-c", "i%-ci%-ve", "r%-cr%-o", "t:" }) do
      if not gc:match(mode) then table.insert(issues, "missing canonical target for '" .. mode:gsub("%%", "") .. "'") end
    end
    if #issues > 0 then
      add_finding("AP-23", "HIGH", "guicursor non-compliant: " .. table.concat(issues, "; "), "lua/core/options.lua", 1, gc, "Compositor wakeups and double-height block cursor regressions.", 'Set o.guicursor = "n-v-c-sm:block-Cursor,i-ci-ve:ver25-Cursor,r-cr-o:hor20-Cursor,t:block-TermCursor,a:blinkon0"')
    else
      pass_rule()
    end
  end

  -- ── AP-24: Bounded Graceful LSP Shutdown (SLA <= 80ms) ────────────────────
  total_rules = total_rules + 1
  local has_leave_pre = autocmds_content:match("VimLeavePre")
  local has_bounded_stop = autocmds_content:match("client%.stop,%s*client,%s*(%d+)")
    or autocmds_content:match("client%.stop%s*%(%s*client%s*,%s*(%d+)%s*%)")
  local has_bounded_wait = autocmds_content:match("vim%.wait%s*%(%s*(%d+)%s*,")
  local has_force_kill = autocmds_content:match("client%.stop,%s*client,%s*true")
    or autocmds_content:match("client%.stop%s*%(%s*client%s*,%s*true%s*%)")

  local t_stop = tonumber(autocmds_content:match("client%.stop,%s*client,%s*(%d+)")
    or autocmds_content:match("client%.stop%s*%(%s*client%s*,%s*(%d+)%s*%)") or "999")
  local t_wait = tonumber(autocmds_content:match("vim%.wait%s*%(%s*(%d+)%s*,") or "999")
  local bounds_ok = (t_stop <= 80) and (t_wait <= 80)

  if not (has_leave_pre and has_bounded_stop and has_bounded_wait and has_force_kill and bounds_ok) then
    add_finding("AP-24", "CRITICAL", "Bounded graceful LSP shutdown supervisor missing or SLA > 80ms", "lua/core/autocmds.lua", 1, "", "Language servers (rust-analyzer, clangd, gopls) stall Neovim exit up to 10s.", "Implement 3-tier shutdown in VimLeavePre: client.stop(80) -> vim.wait(80) -> client.stop(true).")
  else
    pass_rule()
  end

  -- ── AP-25: Prohibition of Naked client.stop(false) ────────────────────────
  total_rules = total_rules + 1
  local ap25_violations = {}
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        local clean = line:match("^%s*(.-)%s*$")
        if clean and not clean:match("^%-%-") then
          if not (f:match("autocmds%.lua") and (clean:match("pcall%(client%.stop,%s*client,%s*80%)") or clean:match("pcall%(client%.stop,%s*client,%s*true%)"))) then
            if clean:match("client%.stop%s*%(%s*client%s*,%s*false%s*%)") or clean:match("client%:stop%s*%(%s*false%s*%)") then
              table.insert(ap25_violations, { file = f, line = i, snippet = clean })
            end
          end
        end
      end
    end
  end
  if #ap25_violations > 0 then
    for _, v in ipairs(ap25_violations) do
      add_finding("AP-25", "HIGH", "Naked / un-bounded client.stop(false) call detected", v.file, v.line, v.snippet, "Lacks fallback timeout; hangs main thread if LSP server deadlocks on shutdown.", "Pass numeric timeout (80ms) or force=true, or rely on central supervisor.")
    end
  else
    pass_rule()
  end

  -- ── AP-26: Floating Window Exit Trapper in QuitPre ────────────────────────
  total_rules = total_rules + 1
  local has_quit_pre = autocmds_content:match("QuitPre")
  local has_win_check = autocmds_content:match("normal_win_count") or autocmds_content:match("nvim_list_wins")
  local has_win_close = autocmds_content:match("nvim_win_close")
  local has_rel_check = autocmds_content:match("config%.relative") or autocmds_content:match("snacks_")
  if not (has_quit_pre and has_win_check and has_win_close and has_rel_check) then
    add_finding("AP-26", "CRITICAL", "Floating window exit trapper missing from QuitPre", "lua/core/autocmds.lua", 1, "", ":q fails with E444 or gets trapped in floating notifications when closing last file.", "Register QuitPre autocmd to dismiss relative windows when normal_win_count <= 1.")
  else
    pass_rule()
  end

  -- ── AP-27: Zero Multi-Domain Spec Duplications (Tree-sitter AST) ──────────
  total_rules = total_rules + 1
  local declared_by = {}
  local ap27_query = [[
    (return_statement
      (expression_list
        (table_constructor
          (field
            [
              (string) @direct_repo
              (table_constructor
                (field
                  (string) @nested_repo
                )
              )
            ]
          )
        )
      )
    )
  ]]

  for _, f in ipairs(plugin_files) do
    local fname = vim.fs.basename(f)
    local code = read_file(f) or ""
    local root = get_tree_root(code)
    if root then
      local ok, query = pcall(vim.treesitter.query.parse, "lua", ap27_query)
      if ok and query then
        for id, node in query:iter_captures(root, code) do
          local text = vim.treesitter.get_node_text(node, code)
          local repo = text:gsub('^["\']', ''):gsub('["\']$', '')
          if repo:match('^[%w_%-%.-]+/[%w_%-%.-]+$') and repo ~= "folke/snacks.nvim" then
            local s_row, _ = node:start()
            if not declared_by[repo] then declared_by[repo] = {} end
            table.insert(declared_by[repo], { file = fname, line = s_row + 1 })
          end
        end
      end
    end
  end

  local duplicates = {}
  for repo, locs in pairs(declared_by) do
    if #locs > 1 then table.insert(duplicates, { repo = repo, locs = locs }) end
  end

  if #duplicates > 0 then
    for _, d in ipairs(duplicates) do
      local loc_str = {}
      for _, l in ipairs(d.locs) do table.insert(loc_str, l.file .. ":" .. l.line) end
      add_finding("AP-27", "CRITICAL", "Plugin '" .. d.repo .. "' declared in multiple domain files", d.locs[1].file, d.locs[1].line, table.concat(loc_str, ", "), "Breaks Bounded Contexts; causes non-deterministic lazy spec merge conflicts.", "Isolate '" .. d.repo .. "' to its single authoritative capability domain.")
    end
  else
    pass_rule()
  end

  -- ── AP-28: Zero Hot-Path Event Attachments (CursorMoved / unthrottled) ────
  total_rules = total_rules + 1
  local ap28_violations = {}
  for _, f in ipairs(plugin_files) do
    local code = read_file(f) or ""
    local lines = vim.split(code, "\n")
    for i, line in ipairs(lines) do
      local clean = line:match("^%s*(.-)%s*$")
      if clean and not clean:match("^%-%-") then
        if clean:match('event%s*=%s*["\']CursorMoved["\']') or clean:match('event%s*=%s*{.-["\']CursorMoved["\']') then
          table.insert(ap28_violations, { file = f, line = i, snippet = clean })
        end
      end
    end
  end
  if #ap28_violations > 0 then
    for _, v in ipairs(ap28_violations) do
      add_finding("AP-28", "HIGH", "Plugin lazy-loads on hot-path event CursorMoved", v.file, v.line, v.snippet, "Blocks UI thread on every cursor movement during buffer navigation.", "Change trigger to VeryLazy or bind to specific keys.")
    end
  else
    pass_rule()
  end

  -- ── SEC-01: Plaintext API Keys & Secrets Scanner ──────────────────────────
  total_rules = total_rules + 1
  local secret_patterns = {
    "sk%-ant%-[0-9a-zA-Z_%-]{20,}",
    "sk%-proj%-[0-9a-zA-Z_%-]{20,}",
    "ghp_[0-9a-zA-Z]{36}",
    "gho_[0-9a-zA-Z]{36}",
    "ANTHROPIC_API_KEY%s*=%s*['\"][^'\"]+['\"]",
    "OPENAI_API_KEY%s*=%s*['\"][^'\"]+['\"]",
  }
  local sec_violations = {}
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        for _, pat in ipairs(secret_patterns) do
          if line:match(pat) then
            table.insert(sec_violations, { file = f, line = i, snippet = line:sub(1, 40) .. "..." })
          end
        end
      end
    end
  end
  if #sec_violations > 0 then
    for _, v in ipairs(sec_violations) do
      add_finding("SEC-01", "CRITICAL", "Plaintext API token or secret detected in Lua codebase", v.file, v.line, v.snippet, "Severe security vulnerability; secret exposure via version control.", "Load secrets exclusively from host environment variables (vim.env.*).")
    end
  else
    pass_rule()
  end

  -- ── NV-01: Neovim 0.12 API Modernization Validator ────────────────────────
  total_rules = total_rules + 1
  local deprecation_patterns = {
    { pat = "vim%.diagnostic%.goto_next", name = "vim.diagnostic.goto_next is deprecated in 0.12; use vim.diagnostic.jump({ count = 1 })" },
    { pat = "vim%.diagnostic%.goto_prev", name = "vim.diagnostic.goto_prev is deprecated in 0.12; use vim.diagnostic.jump({ count = -1 })" },
    { pat = "vim%.lsp%.buf_detach_client", name = "vim.lsp.buf_detach_client is deprecated in 0.12; use client:detach(bufnr)" },
  }
  local nv_violations = {}
  for _, f in ipairs(lua_files) do
    if not f:match("audit") and not f:match("scripts") then
      local code = read_file(f) or ""
      local lines = vim.split(code, "\n")
      for i, line in ipairs(lines) do
        local clean = line:match("^%s*(.-)%s*$")
        if clean and not clean:match("^%-%-") then
          for _, dep in ipairs(deprecation_patterns) do
            if clean:match(dep.pat) then
              table.insert(nv_violations, { file = f, line = i, snippet = clean, desc = dep.name })
            end
          end
        end
      end
    end
  end
  if #nv_violations > 0 then
    for _, v in ipairs(nv_violations) do
      add_finding("NV-01", "HIGH", v.desc, v.file, v.line, v.snippet, "Will break in Neovim 0.13; causes internal deprecation warnings.", "Migrate to canonical Neovim 0.12+ API.")
    end
  else
    pass_rule()
  end

  local duration_ms = (uv.hrtime() - t0) / 1e6

  return {
    repo_root      = P.repo_root,
    total_rules    = total_rules,
    passed_count   = passed_count,
    findings_count = #findings,
    duration_ms    = duration_ms,
    findings       = findings,
  }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PRESENTATION & RUNNER (Interactive Floating Window + Headless TUI / CLI)
-- ═══════════════════════════════════════════════════════════════════════════

function M.run(opts)
  opts = opts or {}
  local is_cli = opts.cli or (#vim.api.nvim_list_uis() == 0)
  local is_json = opts.json or false
  local is_verbose = opts.verbose or false
  local exit_on_fail = opts.exit_on_fail or false

  local res = M.scan_all()

  if is_json then
    local payload = vim.json.encode({
      total_rules = res.total_rules,
      passed = res.passed_count,
      findings_count = res.findings_count,
      duration_ms = res.duration_ms,
      findings = res.findings,
    })
    io.write(payload .. "\n")
    if exit_on_fail and res.findings_count > 0 then os.exit(1) end
    return res
  end

  local lines = {}
  table.insert(lines, "╔══════════════════════════════════════════════════════════════════════════════╗")
  table.insert(lines, "║       x0r/nvim — Industrial AST & Runtime Invariant Auditor (LuaJIT)         ║")
  table.insert(lines, "╚══════════════════════════════════════════════════════════════════════════════╝")
  table.insert(lines, string.format(" Target: %s  │  Runtime: Neovim %s", res.repo_root, vim.version().api_level))
  table.insert(lines, string.format(" Execution SLA: %6.2f ms  │  AST Engine: Tree-sitter C-Parser", res.duration_ms))
  table.insert(lines, "────────────────────────────────────────────────────────────────────────────────")

  if res.findings_count == 0 then
    table.insert(lines, string.format(" [✓ ALL PASS] 100.0%% Invariant Compliance (%d/%d Rules Verified)", res.passed_count, res.total_rules))
    table.insert(lines, "")
    table.insert(lines, "  • Zero Synchronous Shell Calls in Hot Paths")
    table.insert(lines, "  • Zero Repeating LibUV Idle Polling Timers")
    table.insert(lines, "  • Zero Global _G Namespace Leaks")
    table.insert(lines, "  • Zero Indent-0 Module-Scope Mutating Calls (Tree-sitter AST verified)")
    table.insert(lines, "  • Canonical Terminal Cursor Lifecycle & Escape Sequences Guaranteed")
    table.insert(lines, "  • Bounded Graceful LSP Teardown (<= 80ms) & QuitPre Float Trapper Enforced")
    table.insert(lines, "  • Zero Multi-Domain Plugin Spec Duplications")
  else
    table.insert(lines, string.format(" [⚠ FINDINGS DETECTED] %d invariant violations found (%d/%d passed):", res.findings_count, res.passed_count, res.total_rules))
    table.insert(lines, "")
    for _, f in ipairs(res.findings) do
      table.insert(lines, string.format(" [%s] %s (%s:%d)", f.code, f.title, f.file, f.line))
      if f.snippet and f.snippet ~= "" then
        table.insert(lines, string.format("     Snippet:     %s", f.snippet))
      end
      if f.impact and f.impact ~= "" then
        table.insert(lines, string.format("     Impact:      %s", f.impact))
      end
      if f.remediation and f.remediation ~= "" then
        table.insert(lines, string.format("     Remediation: %s", f.remediation))
      end
      table.insert(lines, "")
    end
  end
  table.insert(lines, "────────────────────────────────────────────────────────────────────────────────")

  local text = table.concat(lines, "\n")

  if is_cli then
    print(text)
    if exit_on_fail and res.findings_count > 0 then
      os.exit(1)
    end
  else
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "checkhealth"
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"

    local max_w = math.min(90, vim.o.columns - 4)
    local max_h = math.min(#lines + 2, vim.o.lines - 4)

    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = max_w,
      height = max_h,
      row = math.floor((vim.o.lines - max_h) / 2),
      col = math.floor((vim.o.columns - max_w) / 2),
      style = "minimal",
      border = "rounded",
      title = " Anti-Pattern & Invariant Auditor ",
      title_pos = "center",
    })

    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true, desc = "Close audit" })
    vim.keymap.set("n", "r", function()
      vim.api.nvim_win_close(win, true)
      M.run(opts)
    end, { buffer = buf, silent = true, desc = "Re-run audit" })
  end

  return res
end

-- ── Direct CLI Entrypoint via `nvim -l` ──────────────────────────────────────
if _G.arg and _G.arg[0] and _G.arg[0]:match("antipatterns%.lua$") then
  local cli_opts = {
    cli = true,
    json = false,
    verbose = false,
    exit_on_fail = true,
  }
  for _, a in ipairs(_G.arg) do
    if a == "--json" then cli_opts.json = true end
    if a == "--verbose" or a == "-v" then cli_opts.verbose = true end
  end
  M.run(cli_opts)
end

return M
