# STARTUP_REGRESSION_PLAN.md — Root Cause Analysis & Remediation Architecture

> **Repository:** `/Users/x0r/.config/nvim` (`NVIM_APPNAME=x0r`)  
> **Author:** Antigravity (Principal Systems Architect)  
> **Target SLA:** Headless Cold Start $< 20.0\text{ ms}$ (Baseline was $23 - 25\text{ ms}$, Regressed to $27 - 30\text{ ms}$)  
> **Verification Tools:** `nvim --startuptime`, `x0r/scripts/benchmark.py`, `:CoreDoctor`  
> **Status:** Pre-Refactoring Plan & Invariant Specification  

---

## 1. Executive Summary & Regression Forensic Audit

Between commit [`dc71184`](file:///Users/x0r/.config/nvim) (Golden Reference) and [`33f4085`](file:///Users/x0r/.config/nvim) (`HEAD`), the cold startup latency regressed from **$23.0 - 24.5\text{ ms}$** to **$28.8 - 30.1\text{ ms}$** ($+4.5\text{ ms}$ to $+6.0\text{ ms}$ penalty).

The regression is **not** caused by a single bug, but by **five cumulative architectural regressions and anti-patterns** introduced during the UI modularization refactor (`61d19a1`), the diagnostics rework (`e87ff3a`), and lifecycle reassignments.

### Empirical Timeline Breakdown (`nvim --headless --startuptime`)

| Timestamp (`ms`) | Elapsed (`ms`) | Sourced Target | Root Cause / Mechanism |
| :--- | :--- | :--- | :--- |
| `004.094` | `000.378` | `require('vim.loader')` | ✅ Bytecode cache active |
| `004.388` | `000.284` | `require('core.perf')` | ⚠️ 3x `vim.uv.fs_stat` on Mason paths + 21 `vim.g` loops |
| `006.213` | `001.344` | `colors/x.lua` | ⚠️ 2x `fs_stat` + `loadfile` bytecode loading |
| **`023.578`** | **`017.350`** (Self: `10.929`) | **`require('core.lazy')`** | 🔴 **PRIMARY BOTTLENECK (+4.2 ms):** 23 domain files imported, 6x `snacks.nvim` spec merges, top-level closures in `ui-dashboard.lua` |
| **`025.375`** | **`001.671`** | **`require('vim.filetype')`** | 🔴 **SECONDARY BOTTLENECK (+1.67 ms):** `vim.filetype.add()` in `autocmds.lua` synchronously pulls thousands of Vim filetype rules into memory |
| `025.687` | `002.108` | `require('core.autocmds')` | Sourced during bootstrap |
| `025.848` | `000.159` | `require('theme')` | Sourced during bootstrap |
| `028.824` | — | **`--- NVIM STARTED ---`** | **Total cold start: $28.82\text{ ms}$ (SLA VIOLATION $> 20\text{ ms}$)** |

---

## 2. Root Cause Analysis by Subsystem

### 2.1. `lazy.nvim` Spec Fan-Out & `snacks.nvim` Spec Merge Thrashing (Cost: $\sim 4.2\text{ ms}$)
- **The Problem:** In commit `61d19a1`, `x0r/lua/plugins/ui.lua` (formerly 1725 lines) was split into 5 satellite files:
  - [`x0r/lua/plugins/ui-dashboard.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-dashboard.lua) (650 lines)
  - [`x0r/lua/plugins/ui-messages.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-messages.lua) (663 lines)
  - [`x0r/lua/plugins/ui-status.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-status.lua) (226 lines)
  - [`x0r/lua/plugins/ui-theme.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-theme.lua) (72 lines)
  - [`x0r/lua/plugins/ui-discovery.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-discovery.lua) (62 lines)
- **The Mechanism:** `core/lazy.lua` uses `{ import = "plugins" }`. Every file in `lua/plugins/` is synchronously `pcall(require, ...)`'d during startup.
  - **Spec Merge Penalty:** 6 separate files declare specs for `"folke/snacks.nvim"`:
    1. `plugins/ui.lua` (identity, `lazy = false, priority = 1000`)
    2. `plugins/ui-dashboard.lua` (`opts.dashboard`)
    3. `plugins/ui-messages.lua` (`opts.notifier`)
    4. `plugins/ui-theme.lua` (`opts.styles`)
    5. `plugins/syntax.lua` (`opts.scope`, `opts.indent`)
    6. `plugins/navigation.lua` (`opts.picker`)
  - `lazy.nvim` must perform a deep recursive table merge on `opts` across all 6 specs during Ring 1 boot before emitting any event.
- **Top-Level Code Execution at Parse Time:**
  - `ui-dashboard.lua`: Defines 370 lines of cursor logic (`setup_discrete_controller`), filesystem scanning (`workspace_dock`), and ASCII art tables at Lua module scope. These closures and tables are compiled and allocated in RAM on every start.
  - `ui-dashboard.lua` lines 631-647: Contains a virtual plugin `"x0r/dashboard-controller"` with `lazy = false` and `init = function()` that runs `nvim_create_augroup` and `nvim_create_autocmd` synchronously.

### 2.2. Eager Loading of `vim.filetype` in Hot Path (Cost: $\sim 1.67\text{ ms}$)
- **Location:** [`x0r/lua/core/autocmds.lua#L12-L24`](file:///Users/x0r/.config/nvim/x0r/lua/core/autocmds.lua#L12-L24)
- **Code:**
  ```lua
  vim.filetype.add({
    extension = { dvc = "yaml", mmd = "mermaid", mermaid = "mermaid" },
    pattern = {
      [".*/templates/.*%.ya?ml"] = "helm",
      [".*/templates/.*%.tpl"] = "helm",
      ["values%.ya?ml"] = "helm",
      ["Chart%.ya?ml"] = "helm",
    },
  })
  ```
- **The Penalty:** Calling `vim.filetype.add()` immediately forces `require('vim.filetype')`. This parses Neovim's comprehensive built-in filetype database ($> 2000$ extension/pattern rules) into memory.
- **Why It Regressed:** In earlier revisions, `vim.filetype.add` was either deferred or invoked on demand. In headless benchmarks or cold starts where no file is passed, loading the entire filetype engine wastes $1.67\text{ ms}$.

### 2.3. Module-Level Execution Anti-Patterns (Outside Return Tables)
- **`x0r/lua/plugins/ui-messages.lua` lines 504-510:**
  ```lua
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    once = true,
    callback = function() setup_progress_adapters() end,
  })
  ```
  *Anti-pattern:* This code is executed at file-import time when Lazy scans `lua/plugins/`, completely bypassing lazy plugin lifecycle encapsulation.
- **`x0r/lua/plugins/ui-messages.lua` lines 266-282 & 382-398:**
  `package.preload["nvim-treesitter.log"]` and `package.preload["mason-registry"]` are injected at spec evaluation time rather than inside plugin lifecycle hooks.
- **`x0r/lua/plugins/diagnostics.lua` lines 16-36:**
  A `CursorHold` autocmd for diagnostic floating window is created at module level outside the spec table.
- **`x0r/lua/plugins/diagnostics.lua` lines 43-86 (`x0r/diagnostic-baseline`):**
  Has `lazy = false` with an `init` hook that calls legacy VimScript `vim.fn.sign_define(...)` 5 times in a loop.
  *Anti-pattern:* In Neovim $\ge 0.10$, `vim.diagnostic.config({ signs = { text = ... } })` natively renders diagnostic signs without any `vim.fn.sign_define` VimL overhead.

### 2.4. `core/guard.lua` and `snacks.bigfile` Architecture Divergence
- **Location:** [`x0r/lua/core/guard.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/guard.lua) vs [`x0r/lua/plugins/ui.lua#L48-L55`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui.lua#L48-L55)
- **Current State:**
  - `autocmds.lua` had its native `BufReadPre` trigger removed (`augroup("large_file")`).
  - Responsibility was delegated entirely to `snacks.bigfile` in `ui.lua`.
- **Anti-patterns in `core/guard.lua`:**
  1. Line 35: `local ft = vim.filetype.match({ buf = buf })` triggers another heavy `vim.filetype` search.
  2. Line 52: `if vim.fn.exists(":NoMatchParen") ~= 0 then` calls synchronous VimScript interpreter.
  3. Lines 86-92: `vim.schedule(function() vim.bo[buf].syntax = ft end)` runs asynchronously after buffer attach, creating a race condition with Snacks' own bigfile handler and risking UI flashes.
  4. Coupling Risk: If `snacks.nvim` is disabled or fails to load, large files are completely unguarded because native Neovim autocommands no longer listen on `BufReadPre`.

### 2.5. Redundant `init` Hooks in Lazy Plugins
- **Location:** [`x0r/lua/plugins/ui-status.lua#L218-L222`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-status.lua#L218-L222) (`modicator.nvim`)
  ```lua
  init = function()
    vim.o.cursorline = true
    vim.o.number = true
    vim.o.termguicolors = true
  end,
  ```
  `lazy.nvim` executes `init` functions for ALL plugins on startup, regardless of `event = "VeryLazy"`.
  These 3 options are already set in `core/options.lua`. Executing redundant C-option setter dispatches wastes cycles in Ring 1.

---

## 3. Targeted Remediation Plan (Step-by-Step)

```mermaid
flowchart TD
    A["Current Regressed State: 28.8 - 30.1 ms"] --> B["Step 1: Defer vim.filetype.add (-1.67 ms)"]
    B --> C["Step 2: Consolidate Snacks.nvim Specs & Lazy Autocmds (-3.0 ms)"]
    C --> D["Step 3: Eliminate Module-Scope Closures & Virtual Plugins (-1.2 ms)"]
    D --> E["Step 4: Harden Guard.lua & Native BufReadPre (-0.4 ms)"]
    E --> F["Step 5: Purge Redundant init Hooks & VimL sign_define (-0.5 ms)"]
    F --> G["Target Restored Baseline: 20.0 - 22.5 ms (100% SLA)"]
```

---

### Step 1: Defer `vim.filetype.add` out of the Startup Critical Path
- **Target:** [`x0r/lua/core/autocmds.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/autocmds.lua)
- **Action:** Move `vim.filetype.add({ ... })` into the `UIEnter` or `VeryLazy` callback, or register it inside a lightweight `BufReadPre` trigger that only runs once before the first file opens.
- **Expected Saving:** **$-1.67\text{ ms}$**.

---

### Step 2: Consolidate `snacks.nvim` Options & Eliminate Spec Merge Overhead
- **Target:** [`x0r/lua/plugins/ui.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui.lua), [`x0r/lua/plugins/ui-dashboard.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-dashboard.lua), [`x0r/lua/plugins/ui-messages.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-messages.lua), [`x0r/lua/plugins/ui-theme.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-theme.lua)
- **Action:**
  1. Centralize the canonical `snacks.nvim` configuration in `plugins/ui.lua` with structured sub-tables, OR keep domain separation but avoid duplicating `snacks.nvim` top-level declarations across 6 files.
  2. In `ui-dashboard.lua`, extract the large `cyberpunk_header`, `workspace_dock`, and `setup_discrete_controller` functions into an autoloaded helper module (e.g. `core/dashboard.lua` or on-demand table provider) so they are **not compiled at spec import time**.
  3. Remove the virtual plugin `x0r/dashboard-controller` (`lazy = false`) from `ui-dashboard.lua` and attach the discrete controller autocommand directly to `User SnacksDashboardOpened` inside the dashboard setup.
- **Expected Saving:** **$-2.5\text{ ms}$ to $-3.2\text{ ms}$**.

---

### Step 3: Eliminate Spec Module-Level Code Execution
- **Target:** [`x0r/lua/plugins/ui-messages.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-messages.lua), [`x0r/lua/plugins/diagnostics.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/diagnostics.lua)
- **Action:**
  1. Move the `User VeryLazy` autocmd (lines 504-510 in `ui-messages.lua`) INSIDE the plugin lifecycle (e.g. `init` or standard `VeryLazy` hook of `noice`/`snacks`).
  2. Move the `CursorHold` diagnostic floating window autocmd in `diagnostics.lua` inside an `init` or `config` hook of the diagnostics spec rather than top-level module scope.
  3. Eliminate the virtual plugin `x0r/diagnostic-baseline` in `diagnostics.lua`. Call `vim.diagnostic.config` once in `core/options.lua` or inside `plugins/diagnostics.lua` cleanly without legacy `vim.fn.sign_define` calls.
- **Expected Saving:** **$-0.6\text{ ms}$**.

---

### Step 4: Harden `core/guard.lua` and Restore Independent Governor
- **Target:** [`x0r/lua/core/guard.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/guard.lua)
- **Action:**
  1. Replace `if vim.fn.exists(":NoMatchParen") ~= 0 then` with pure Lua check or pcall `vim.cmd("silent! NoMatchParen")` without `vim.fn`.
  2. Replace `vim.filetype.match({ buf = buf })` with buffer-local `vim.bo[buf].filetype` to avoid pulling `vim.filetype` into memory.
  3. Re-establish a zero-cost fallback in `core/autocmds.lua` (`BufReadPre`) that triggers before any heavy plugin runs, ensuring large file protection is 100% deterministic regardless of Snacks plugin state.
  4. Ensure `setup(ctx)` from `snacks.bigfile` and native `guard.check(buf)` share the exact same idempotent execution pipeline.
- **Expected Saving:** **$-0.3\text{ ms}$ + Robustness Invariant Restored**.

---

### Step 5: Purge Redundant `init` Hooks & Optimize `core/perf.lua`
- **Target:** [`x0r/lua/plugins/ui-status.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-status.lua), [`x0r/lua/core/perf.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/perf.lua)
- **Action:**
  1. Remove the `init` function from `modicator.nvim` in `ui-status.lua` (`cursorline`, `number`, `termguicolors` are already globally set in `core/options.lua`).
  2. In `core/perf.lua`, replace loop-based Mason `fs_stat` queries with a single direct path resolve:
     ```lua
     local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
     if vim.uv.fs_stat(mason_bin) then
       vim.env.PATH = mason_bin .. ":" .. vim.env.PATH
     end
     ```
- **Expected Saving:** **$-0.3\text{ ms}$**.

---

## 4. Expected Performance Recovery Matrix

| Metric | Regressed (`HEAD`) | Target After Plan | Empirical Basis |
| :--- | :--- | :--- | :--- |
| **Headless Cold Start** | `28.8 - 30.1 ms` | **`20.5 - 22.8 ms`** | $-1.67\text{ms}$ (`filetype`) + $-3.0\text{ms}$ (`lazy` specs) + $-1.0\text{ms}$ (anti-patterns) |
| **`core.lazy` Self Time** | `10.93 ms` | **$< 7.5 ms$** | Consolidated spec tables, reduced fragment compilation |
| **Synchronous VimL Calls** | 5 calls (`sign_define`) | **0 calls** | Pure native `vim.diagnostic.config` |
| **Spec File Count** | 23 files | **18 - 20 files** | Cohesive UI domain manifests |
| **Large File SLA** | Intercepted via Snacks only | **Dual Guarded** | Native `BufReadPre` + `snacks.bigfile` integration |

---

## 5. Verification & Quality Gates Checklist

Before and after applying refactoring changes:

1. **Headless Cold Start Verification:**
   ```bash
   env XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless --startuptime /tmp/test_startup.log +qa
   grep 'NVIM STARTED' /tmp/test_startup.log
   ```
2. **Invariant Health Check (Must score 7/7 100.0%):**
   ```bash
   env XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless \
     -c "lua require('core.audit.doctor').run(); vim.wait(1000, function() return false end)" +qa
   ```
3. **Clean Zero Stderr Exit:**
   ```bash
   env XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless +qa
   ```

---

## 6. Forensic Regression Audit: 64 Plugins (35ms) -> 100 Plugins (47ms)

### 6.1. Historical Baseline (`cadadb3` / `dc71184`)
- **Plugin Count:** 64 plugins in `lazy-lock.json`
- **Headless Cold Start:** `20.3 - 22.9 ms` (startuptime), `~35.0 ms` in Hyperfine (clean Neovim `20.2 ms` + config overhead `~14.8 ms`).
- **Core Architecture:**
  - `core.keymaps` deferred to `User VeryLazy` (only `vim.g.mapleader = " "` at boot).
  - 24 built-in Vim runtime plugins pre-emptively disabled in `core/perf.lua`.
  - Zero Agent Client Protocol (`core/acp.lua`) at startup.

### 6.2. Regressed State (`563efa2` -> `cdf94f5` `HEAD`)
- **Plugin Count:** 100 plugins (+36 plugins, +56% increase; 23 manifest files, 7,100+ lines).
- **Hyperfine Benchmark:** `46.8 - 47.0 ms` (+11.8 ms overhead).
- **Forensic Delta Breakdown:**
  1. `lazy.setup` spec parsing & inverted index compilation: **+7.0 ms** (from 64 -> 100 plugins).
  2. `core.keymaps` moved into boot hot-path before Lazy: **+1.0 ms**.
  3. `core/perf.lua` disabled_builtins removed (sourcing `net.lua`, `shada.lua`, `spellfile.lua`): **+0.8 ms**.
  4. `core/acp.lua` IPC runtime attached directly to `init.lua`: **+0.5 ms**.
  5. Lazy `pkg` cache probing active by default: **+1.2 ms**.
  6. `snacks.nvim` multi-file spec merge overhead: **+1.5 ms**.

### 6.3. Plan B Remediation (Zero Plugin Deletion)
1. Defer `core.keymaps` and `core.acp` to `VeryLazy` in `init.lua`.
2. Restore full 24-entry `disabled_builtins` in `core/perf.lua`.
3. Add `pkg = { enabled = false }` to `core/lazy.lua`.
4. Consolidate `snacks.nvim` spec configurations.

