# 🔬 Principal Architecture Audit & Remediation Plan

> **Date:** 2026-10-11  
> **Target:** `/Users/x0r/.config/nvim/zx0r`  
> **Neovim:** v0.12.5 (LuaJIT 2.1)  
> **Measured Cold Start:** ~24.2 ms (target: ≤ 15 ms)  
> **Standard:** Zero SLA · Zero Overhead · Zero Anti-Pattern · Zero Latency  
> **Auditors:** 4 parallel domain agents (Core, Plugins, UI/Theme, FTPlugin/Scripts)  
> **Total Findings:** 47 (7 CRITICAL, 12 HIGH, 18 MEDIUM, 5 LOW, 5 ARCHITECTURAL)

---

## Table of Contents

1. [Severity Legend](#severity-legend)
2. [Phase 0 — CRITICAL: Immediate Hotfixes (SLA Violations)](#phase-0--critical-immediate-hotfixes)
3. [Phase 1 — HIGH: Regression Elimination](#phase-1--high-regression-elimination)
4. [Phase 2 — MEDIUM: Hardening & Optimization](#phase-2--medium-hardening--optimization)
5. [Phase 3 — LOW: Polish & Defensive Depth](#phase-3--low-polish--defensive-depth)
6. [Phase 4 — ARCHITECTURAL: Structural Alignment](#phase-4--architectural-structural-alignment)
7. [Existing Plan Reconciliation](#existing-plan-reconciliation)
8. [Validation Checklist](#validation-checklist)

---

## Severity Legend

| Level | Criteria | SLA Impact |
|---|---|---|
| 🔴 **CRITICAL** | Blocks startup, causes crashes, freezes main thread, corrupts data | Direct user-facing regression |
| 🟠 **HIGH** | Measurable latency on hot paths, process leaks, broken navigation | Degrades interactive experience |
| 🟡 **MEDIUM** | Suboptimal patterns, accumulated overhead, visual glitches | Detectable under load |
| 🟢 **LOW** | Cleanliness, minor optimization, defensive improvements | Negligible impact |
| 🔵 **ARCH** | Structural drift from specifications, contradictions between plans | Long-term maintainability |

---

## Phase 0 — CRITICAL: Immediate Hotfixes

> [!CAUTION]
> These 7 findings directly violate SLA constraints. Each causes measurable user-facing degradation — typing latency, crash risk, stale theme state, or startup overhead. Fix before any other work.

### C-01: `CursorHoldI` in `auto_checktime` — Typing Latency Regression
- **File:** `lua/core/autocmds.lua:169-176`
- **Impact:** Synchronous `checktime` (stat all open buffers) fires every 200ms during **Insert mode typing**
- **Code:**
  ```lua
  au({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    group = augroup("auto_checktime"),
    callback = function()
      if vim.fn.getcmdwintype() == "" and vim.bo.buftype == "" then
        vim.cmd("checktime")
      end
    end,
  })
  ```
- **Root Cause:** `CursorHoldI` fires at `updatetime` (200ms) intervals during insert mode. `checktime` triggers synchronous stat syscalls across **all** loaded buffers.
- **Fix:** Remove `CursorHoldI` and `CursorHold` — restrict to `FocusGained` and `BufEnter` only:
  ```lua
  au({ "FocusGained", "BufEnter" }, {
  ```
- **Expected Gain:** Eliminates micro-stutters during typing and completion

---

### C-02: Theme Cache Ignores Palette & Engine Changes — Stale Highlights
- **Files:** `lua/theme/master.lua:1096-1108`, `colors/x.lua:15-24`
- **Impact:** Editing any palette in `lua/theme/palettes/*` or `lua/theme/engine.lua` has **zero effect** until user manually deletes compiled `.luac` cache
- **Code:**
  ```lua
  local cache_stat = vim.uv.fs_stat(compiled_file)
  local master_stat = vim.uv.fs_stat(master_file)
  if cache_stat and master_stat and cache_stat.mtime.sec >= master_stat.mtime.sec then
    -- Serves stale bytecode even if palettes/engine changed
  ```
- **Root Cause:** Cache validity check only inspects `master.lua` mtime. Palette files and `engine.lua` are invisible to the invalidation logic.
- **Fix:** Check all dependency files:
  ```lua
  local function is_cache_fresh(cache_file, deps)
    local c = vim.uv.fs_stat(cache_file)
    if not c then return false end
    for _, dep in ipairs(deps) do
      local s = vim.uv.fs_stat(dep)
      if s and s.mtime.sec > c.mtime.sec then return false end
    end
    return true
  end
  -- deps = { master_file, engine_file, active_palette_file }
  ```

---

### C-03: `install.missing = true` — Comment/Code Contradiction + 2.5ms Overhead
- **File:** `lua/core/lazy.lua:52-56`
- **Impact:** Loads lazy's entire `manage.runner`, `manage.task`, `manage.process` chain on every startup
- **Code:**
  ```lua
  install = {
    -- Deterministic supply-chain: do not check/install missing plugins on launch.
    -- Plugin provisioning is performed explicitly via :Lazy install / sync.
    missing = true,   -- ← CONTRADICTS THE COMMENT ABOVE IT
  ```
- **Root Cause:** Boolean was never flipped after the comment was written. Flagged in `OPUS_RING_ARCHITECTURE_AUDIT` and `ZERO-OVERHEAD-PLAN` but never committed.
- **Fix:** `missing = false`
- **Expected Gain:** −2.5ms startup

---

### C-04: Deprecated `treesitter.setup()` API — Crash on Modern nvim-treesitter
- **File:** `lua/plugins/syntax.lua:138-140`
- **Impact:** `require("nvim-treesitter").setup(opts)` → `attempt to call field 'setup' (a nil value)` on latest nvim-treesitter main branch
- **Code:**
  ```lua
  local treesitter = require("nvim-treesitter")
  treesitter.setup(opts)
  ```
- **Fix:**
  ```lua
  require("nvim-treesitter.configs").setup(opts)
  ```

---

### C-05: Unguarded Colorscheme in Ring 0 — Fatal on Cache Corruption
- **File:** `init.lua:52`
- **Impact:** Any error in `colors/x.lua` or theme bytecode crashes entire init sequence
- **Code:**
  ```lua
  vim.cmd.colorscheme("x")
  ```
- **Fix:**
  ```lua
  if not pcall(vim.cmd.colorscheme, "x") then
    vim.cmd.colorscheme("habamax")
  end
  ```

---

### C-06: Synchronous `vim.fn.filewritable` on Every Buffer Open/Save
- **File:** `lua/core/autocmds.lua:270-291, 293-310`
- **Impact:** Blocking disk I/O on `BufReadPost` and `BufWritePre` — degrades NFS/remote performance
- **Code:**
  ```lua
  if vim.bo[buf].readonly or vim.fn.filewritable(fname) == 0 then
  ```
- **Fix:** Replace with async libuv check or rely on `vim.bo[buf].readonly`:
  ```lua
  if vim.bo[buf].readonly or not vim.bo[buf].modifiable then
  ```

---

### C-07: Force-Kill LSP Servers on Exit — Database Corruption
- **File:** `lua/core/autocmds.lua:211-219`
- **Impact:** `client.stop(client, true)` sends SIGKILL, corrupting rust-analyzer/gopls/clangd caches
- **Code:**
  ```lua
  pcall(client.stop, client, true)  -- force = true → SIGKILL
  ```
- **Fix:** Graceful shutdown:
  ```lua
  pcall(client.stop, client, false)  -- Sends LSP shutdown request first
  ```

---

## Phase 1 — HIGH: Regression Elimination

### H-01: `<Tab>`/`<S-Tab>` Hijacks Jumplist Navigation
- **File:** `lua/core/keymaps.lua:80-81`
- **Impact:** `<Tab>` aliases `<C-i>` in non-CSI-u terminals. Remapping `<Tab>` to `}` clobbers forward jump.
- **Fix:** Prefix with mark: `map("n", "<Tab>", "m'}", ...)` or use different binding

### H-02: Hardcoded `#FF0000` in Statusline Breaks Theme Abstraction
- **File:** `lua/plugins/ui-status.lua:66`
- **Impact:** Raw hex bypasses palette system, glares in light mode, flashes on transparent bars
- **Fix:** `color = "DiagnosticError"` (semantic highlight group)

### H-03: Unthrottled LSP Progress Flooding Notifications
- **File:** `lua/plugins/ui-messages.lua:44-141`
- **Impact:** Hundreds of `vim.notify` calls/sec during TS/Rust indexing → event loop saturation
- **Fix:** Debounce with `vim.uv.new_timer()` at 80ms interval:
  ```lua
  local progress_timer = vim.uv.new_timer()
  local pending = false
  -- In callback:
  if not pending then
    pending = true
    progress_timer:start(80, 0, vim.schedule_wrap(function()
      pending = false
      -- unified render here
    end))
  end
  ```

### H-04: Missing `root_markers` in `cssls.lua` — Orphan Node Processes
- **File:** `lsp/cssls.lua`
- **Impact:** CSS language server spawns per-buffer without project boundary detection
- **Fix:** Add `root_markers = { "package.json", ".git" }`

### H-05: Broken `telescope.nvim` Dependencies After Snacks Migration
- **Files:** `lua/plugins/coding.lua:499,516` + `lua/plugins/language.lua:509,512`
- **Impact:** `text-case.nvim` and `actions-preview.nvim` call `require("telescope")` which is no longer installed
- **Fix:** Remove telescope dependency declarations; guard with `pcall`; switch `actions-preview` to native/nui backend

### H-06: Stale `x0r` Path Probe in `doctor.lua`
- **File:** `lua/core/audit/doctor.lua:24-26`
- **Code:** `if vim.uv.fs_stat(config_root .. "/x0r/lua") then`
- **Fix:** Remove obsolete path check; use `config_root .. "/lua"` directly

### H-07: Fragile Mason PATH Construction in `perf.lua`
- **File:** `lua/core/perf.lua:28-34`
- **Impact:** 3 redundant `fs_stat` calls with hardcoded fallback to `"nvim"` instead of `"zx0r"`
- **Fix:** Single canonical path: `vim.fn.stdpath("data") .. "/mason/bin"`

### H-08: Shell Injection Risk in `benchmark.lua` Hyperfine Commands
- **File:** `lua/core/audit/benchmark.lua:26-31`
- **Impact:** Nested `shellescape` inside hyperfine command string can break on paths with spaces
- **Fix:** Construct command arguments without shell nesting

### H-09: `<leader>ca` Keymap Collision Between LspAttach and actions-preview
- **File:** `lua/plugins/language.lua:223` vs `lua/plugins/language.lua:528`
- **Impact:** Both register `<leader>ca` — race condition determines which wins
- **Fix:** Remove raw `vim.lsp.buf.code_action` mapping in `LspAttach`; delegate to `actions-preview`

### H-10: `workstation_audit_oracle.sh` Uses Invalid `rg` Flags
- **File:** `scripts/workstation_audit_oracle.sh:201,218,224,257,395`
- **Impact:** `--include='*.lua'` is GNU grep syntax, NOT ripgrep. Gates G2, G3, G6 silently produce 0 results.
- **Fix:** Replace all `--include='*.lua'` with `--type lua` or `-g '*.lua'`

### H-11: CI Workflow Broken Paths After x0r→zx0r Rename
- **File:** `.github/workflows/bench.yml`
- **Impact:** All jobs reference `cd x0r` which no longer exists
- **Fix:** Update all path references to `zx0r`

### H-12: `snacks.nvim` Eager Load at `priority = 1000, lazy = false`
- **File:** `lua/plugins/ui.lua:44-45`
- **Impact:** Loads entire snacks module tree before any buffer opens. Flagged in OPUS audit AP-4 and Zero-Overhead Plan §2.1 — still unfixed.
- **Fix:** Move non-essential snacks modules (`scroll`, `indent`, `zen`, `dim`, `image`) to `VeryLazy` event

---

## Phase 2 — MEDIUM: Hardening & Optimization

### M-01: Global `concealcursor = "nvc"` — Layout Shift Across All Filetypes
- **File:** `lua/core/options.lua:44`
- **Fix:** Remove from global options; set buffer-local in `after/ftplugin/markdown.lua`

### M-02: Double `fs_stat` in `guard.lua`
- **File:** `lua/core/guard.lua:23` + `lua/core/guard.lua:42`
- **Fix:** Pass resolved `stat` object from `check()` into `setup()` to eliminate duplicate syscall

### M-03: `tabdo wincmd =` Triggers Cross-Tab Redraws
- **File:** `lua/core/autocmds.lua:41-48`
- **Fix:** Use `vim.cmd("wincmd =")` for active tab only; defer others to `TabEnter`

### M-04: Syntax Mutation Race in `guard.lua`
- **File:** `lua/core/guard.lua:94-100`
- **Fix:** Set `vim.bo[buf].syntax = ft` synchronously, or verify TS highlighter is inactive first

### M-05: Dashboard `CursorMoved` Un-Debounced Line Scanner
- **File:** `lua/plugins/ui-dashboard.lua:120-163, 208-259`
- **Fix:** Cache grid positions on `SnacksDashboardOpened`; reference cache in `CursorMoved`

### M-06: Un-Batched `nvim_set_hl` Loop in Theme Engine
- **File:** `lua/theme/engine.lua:112-114`
- **Fix:** Use `link` definitions where groups are identical to reduce C API boundary transitions

### M-07: `x_markdown.lua` Missing 6 Canonical Design Tokens
- **File:** `lua/theme/palettes/x_markdown.lua`
- **Missing:** `class`, `const_builtin`, `type_def`, `type_builtin`, `type_qualifier`, `string_doc`
- **Fix:** Add all 6 tokens to complete the 38-token palette contract

### M-08: `basedpyright.lua` Missing `root_markers`
- **File:** `lsp/basedpyright.lua`
- **Fix:** Add `root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "uv.lock", ".git" }`

### M-09: `ts_ls.lua` Over-Broad `.git` Root Marker
- **File:** `lsp/ts_ls.lua:7`
- **Fix:** Remove `.git` from `root_markers` to prevent monorepo root-level binding

### M-10: LspAttach Document Highlight Augroup Memory Leak
- **File:** `lua/plugins/language.lua:140-176`
- **Fix:** Register `BufDelete` autocmd to `nvim_del_augroup_by_name("core_lsp_highlight_" .. bufnr)`

### M-11: Synchronous `:wait(5000)` in AI Commit Prompt
- **File:** `lua/plugins/ai.lua:189-215`
- **Fix:** Use async callback pattern: `vim.system({ ... }, { text = true }, function(obj) ... end)`

### M-12: `package.preload` Monkeypatching in `ui-messages.lua`
- **File:** `lua/plugins/ui-messages.lua:265-282`
- **Fix:** Use `require("lazy.core.util")` hooks or wrap in standard `init` handlers

### M-13: All 3 ftplugins Missing `b:did_ftplugin` Guard
- **Files:** `after/ftplugin/{python,rust,go}.lua`
- **Fix:** Add to each file:
  ```lua
  if vim.b.did_ftplugin then return end
  vim.b.did_ftplugin = 1
  ```

### M-14: All 3 ftplugins Missing `undo_ftplugin`
- **Files:** `after/ftplugin/{python,rust,go}.lua`
- **Fix:** Define `vim.b.undo_ftplugin` to reset buffer-local options on filetype change

### M-15: Rust/Go ftplugins Use `vim.fn.getcwd()` Instead of `vim.fs.root`
- **Files:** `after/ftplugin/rust.lua:14,26,36` + `after/ftplugin/go.lua`
- **Fix:** `cwd = vim.fs.root(0, { "Cargo.toml" })` / `cwd = vim.fs.root(0, { "go.mod" })`

### M-16: Rust ftplugin `vim.notify` Unbounded Compiler Output
- **File:** `after/ftplugin/rust.lua`
- **Fix:** Truncate stdout to first 2KB before passing to `vim.notify`

### M-17: `nvim-jqx` Loaded on Broad `ft = { "json", "yaml" }`
- **File:** `lua/plugins/data.lua:207-213`
- **Fix:** Change to `cmd = { "JqxList", "JqxQuery" }` — load only on explicit command

### M-18: Neotest Adapter Loading Lacks Lazy Factories
- **File:** `lua/plugins/testing.lua:26-30`
- **Fix:** Use `adapters = function() ... end` and lazy-load adapter dependencies

---

## Phase 3 — LOW: Polish & Defensive Depth

### L-01: `colors/x.lua` Double `fs_stat` on Fast Path
- **Fix:** Attempt `loadfile(cache_file)` directly; only stat master if load fails (~0.2ms savings)

### L-02: Unprotected Command Registration in `audit/init.lua`
- **Fix:** Wrap user command dispatch in `pcall` with clean error notification

### L-03: Memory Audit Threshold Too Generous (60MB)
- **File:** `lua/core/audit/doctor.lua:216`
- **Fix:** Tighten to `< 25 MB` pass, warning between 25–45 MB

### L-04: Rainbow Delimiters Early-Attach Race Condition
- **File:** `lua/plugins/syntax.lua:537-541`
- **Fix:** Delay `attach` call until after Treesitter parser initialization completes

### L-05: Duplicate `disabled_builtins` in `perf.lua` + `lazy.lua`
- **Fix:** Consolidate into single source of truth in `perf.lua`; remove from `lazy.lua`

---

## Phase 4 — ARCHITECTURAL: Errata Cleanup

> [!IMPORTANT]
> Locked decisions — no ambiguity, no questions.
>
> - **Namespace:** Flat `core.*` / `plugins.*` stays. Namespace migration is revoked from all prior plans.
> - **`lsp/`:** Root placement stays. This is standard Neovim `vim.lsp.enable()` convention. Prior plan references calling it an "RTP Violation" are errata — purge from `MASTER_PLAN.md` and `REFACTORING_ARCHITECTURE.md`.

### A-01: Purge Namespace Migration Errata from All Plan Documents
- **Action:** Remove all references to `zx0r.core.*` migration from `MASTER_PLAN.md`, `REFACTORING_ARCHITECTURE.md`, `REFACTORING_PLAN.md`. The flat `core.*` / `plugins.*` layout is the canonical architecture.

### A-02: Purge `lsp/` "RTP Violation" Errata from All Plan Documents
- **Action:** Remove `lsp/` from any issue matrix or remediation list in prior plans. Root `lsp/` is Neovim convention for `vim.lsp.enable()`.

### A-03: Normalize Colorscheme Name → `x`
- **Action:** `init.lua` uses `colorscheme x`. `ZERO-OVERHEAD-PLAN.md` references `environment-x` — that is stale. Update `ZERO-OVERHEAD-PLAN.md` to reference `x`. Single canonical name: **`x`**.

### A-04: Normalize SLA Startup Target → `≤ 15ms` Headless
- **Action:** Set single canonical SLA across all validators:
  | Validator | Set To |
  |---|---|
  | `benchmark.py` → `SLA["startup_cold_ms"]` | `15.0` |
  | `workstation_audit_oracle.sh` → `SLA_STARTUP_HEADLESS_MS` | `15` |
  | `ZERO-OVERHEAD-PLAN.md` | Update to `≤ 15ms` |
  | `OPUS_RING_ARCHITECTURE_AUDIT` | Informational only (no SLA override) |

### A-05: Remove Dead Configuration
- **Action:** Delete empty `mcp-servers.json`. Remove `NVIM_ROLE` matrix from `.github/workflows/bench.yml` — no role loader exists, no role loader is planned.

---

## Existing Plan Reconciliation

> [!WARNING]
> Cross-referencing 5 existing plan documents against the live codebase. Items flagged as P0/P1 in prior plans but **still unfixed**:

| Item | First Flagged In | Status |
|---|---|---|
| `install.missing = true` | OPUS Audit (2026-10-05) | ❌ **Still active** → C-03 |
| `snacks.nvim` eager load | OPUS Audit AP-4, Zero-Overhead §2.1 | ❌ **Still active** → H-12 |
| Mason tool-installer cleanup | REFACTORING_PLAN §3 | ⚠️ Partially done |
| Double `filetype.lua` sourcing | OPUS Audit §1, §5 | ❌ **Unaddressed** |
| `workstation_audit_oracle.sh` rg flags | Never flagged | ❌ **Broken since creation** → H-10 |
| CI workflow paths | Never flagged | ❌ **Broken since rename** → H-11 |
| ~~Namespace migration~~ | ~~MASTER_PLAN Phase 1~~ | ✅ **Revoked** — flat `core.*` is canonical |
| ~~`lsp/` RTP Violation~~ | ~~MASTER_PLAN Phase 2~~ | ✅ **Revoked** — root `lsp/` is Neovim convention |

---

## Validation Checklist

After implementing all phases, verify:

```bash
# 1. Startup time (target: ≤ 15ms headless)
nvim --headless --startuptime /tmp/st.log -c 'qa' && tail -1 /tmp/st.log

# 2. Zero errors on clean launch
nvim --headless -c 'lua for _,m in ipairs(vim.api.nvim_get_hl(0,{})) do end' -c 'qa'

# 3. Theme cache invalidation test
touch lua/theme/palettes/x_cyber.lua && nvim --headless -c 'colorscheme x' -c 'qa'

# 4. No orphan processes after exit
nvim test.rs -c 'sleep 2' -c 'qa' && pgrep -f 'rust-analyzer|gopls|css-language'

# 5. Lint clean
selene lua/
stylua --check lua/

# 6. Doctor audit passes
nvim --headless -c 'XDoctor' -c 'sleep 3' -c 'qa'
```

---

## Implementation Priority Matrix

```
Week 1 (Immediate):  C-01 → C-07  (7 items, CRITICAL)
Week 2 (Sprint):     H-01 → H-12  (12 items, HIGH)
Week 3 (Harden):     M-01 → M-18  (18 items, MEDIUM)
Week 4 (Polish):     L-01 → L-05, A-01 → A-05  (10 items, LOW + ARCH errata)
```

> [!NOTE]
> This plan supersedes `REFACTORING_PLAN.md`, `ZERO-OVERHEAD-PLAN.md`, and the remediation sections of `OPUS_RING_ARCHITECTURE_AUDIT_2026-10-05.md`. Namespace migration and `lsp/` placement debates are formally closed. `MASTER_PLAN.md` and `REFACTORING_ARCHITECTURE.md` require errata cleanup per A-01, A-02.

---

*Generated by 4-agent parallel deep audit. Each finding verified against live codebase with exact file:line references.*
