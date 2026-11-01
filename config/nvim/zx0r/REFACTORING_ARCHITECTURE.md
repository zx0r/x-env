# x0r/nvim → zx0r Namespace Migration & Architecture Refactoring

> **Document Class:** Principal Solution Architect Specification
> **Status:** ANALYSIS COMPLETE — READY FOR EXECUTION
> **Target:** `x0r/nvim` → `zx0r`-namespaced Capability-Oriented Architecture
> **Scope:** 3 Architectural Corrections + UI Modernization + Anti-Pattern Audit

---

## Executive Diagnosis

After systematic analysis of **all 42 Lua modules**, **3 LSP configs**, **22 syntax themes**, **1
colorscheme engine**, **2 existing plans**, and the **AGENTS.md specification**, I've identified the
following architectural corrections:

### Critical Issue Matrix

| #   | Issue                                  | Severity    | Current                                           | Required                                                                |
| --- | -------------------------------------- | ----------- | ------------------------------------------------- | ----------------------------------------------------------------------- |
| 1   | **RTP Violation: `lsp/`**              | 🔴 Critical | `x0r/lsp/*.lua` in root                           | `x0r/lua/zx0r/lsp/*.lua` inside `lua/`                                  |
| 2   | **`colors/syntax/` pollution**         | 🟡 High     | 21 files in `colors/syntax/`                      | Only entry point in `colors/`, syntax logic to `lua/zx0r/theme/syntax/` |
| 3   | **Missing namespace**                  | 🟡 High     | `require("core.X")` / `require("plugins")`        | `require("zx0r.core.X")` / `{ import = "zx0r.plugins" }`                |
| 4   | **`perf.lua` GC API misuse**           | 🟡 Medium   | `pcall(collectgarbage, "incremental", { ... })`   | LuaJIT uses `setpause`/`setstepmul`, not tables                         |
| 5   | **Module header naming inconsistency** | 🟠 Low      | Mix of `-- core/X.lua` and `-- lua/plugins/X.lua` | Uniform `-- zx0r/core/X.lua` namespace-prefixed                         |
| 6   | **`AGENTS.md` require paths stale**    | 🟠 Low      | References `require("core.X")`                    | Must match new `require("zx0r.core.X")`                                 |

---

## Phase 1: Namespace Migration (`core/` → `zx0r/core/`, `plugins/` → `zx0r/plugins/`)

### 1.1 Directory Structure Transformation

```text
BEFORE:                              AFTER:
x0r/lua/core/                   →    x0r/lua/zx0r/core/
x0r/lua/core/audit/             →    x0r/lua/zx0r/core/audit/
x0r/lua/plugins/                →    x0r/lua/zx0r/plugins/
x0r/lsp/                        →    x0r/lua/zx0r/lsp/
x0r/colors/syntax/              →    x0r/lua/zx0r/theme/syntax/
                                     (colors/environment-x.lua stays)
```

### 1.2 File-Level Changes

| File                       | Change Required                                                      |
| -------------------------- | -------------------------------------------------------------------- |
| `init.lua`                 | `require("core.X")` → `require("zx0r.core.X")`                       |
| `core/lazy.lua`            | `{ import = "plugins" }` → `{ import = "zx0r.plugins" }`             |
| `core/autocmds.lua`        | `require("core.guard")` → `require("zx0r.core.guard")`               |
| `core/audit/init.lua`      | `require("core.audit.doctor")` → `require("zx0r.core.audit.doctor")` |
| `core/audit/doctor.lua`    | All internal `require("core.X")` paths                               |
| `core/audit/benchmark.lua` | All internal `require("core.X")` paths                               |
| `colors/environment-x.lua` | Any `require("core.X")` references                                   |
| `AGENTS.md`                | All `require()` path examples                                        |
| `ZERO-OVERHEAD-PLAN.md`    | `require("core.X")` references                                       |

### 1.3 Styler.nvim Theme Path Update

The `colors/syntax/` subdirectory files are referenced via `styler.nvim` in `ui.lua`:

```lua
-- BEFORE:
themes = { python = { colorscheme = "syntax/neon" }, ... }

-- AFTER (syntax themes moved to lua/zx0r/theme/syntax/):
-- colors/ directory has only entry-point colorschemes
-- Styler references now point to runtime-registered schemes
```

> [!IMPORTANT] `styler.nvim` uses Neovim's `:colorscheme` command internally. Files in `colors/` are
> auto-discovered by Neovim's RTP. Moving syntax files out of `colors/` requires registering them as
> colorschemes through Lua or keeping minimal proxy files.
>
> **Best approach:** Keep `colors/syntax/*.lua` files as **thin proxies** that require the actual
> logic from `lua/zx0r/theme/syntax/`. This preserves `:colorscheme syntax/X` compatibility while
> moving implementation logic into the namespace.

---

## Phase 2: RTP Violation Fix (lsp/)

### 2.1 Move `lsp/` into Lua namespace

```bash
# Current: x0r/lsp/jsonls.lua — NOT inside lua/, breaks require()
# Target:  x0r/lua/zx0r/lsp/jsonls.lua — properly namespaced

mv x0r/lsp/ x0r/lua/zx0r/lsp/
```

> [!NOTE] Neovim ≥ 0.12 auto-discovers `lsp/` in runtime path for `vim.lsp.enable()`. After moving
> to `lua/zx0r/lsp/`, we need to ensure the LSP configs are still discoverable by registering them
> explicitly or keeping the `lsp/` directory at the RTP root as well. The cleanest approach is to
> keep `lsp/` at root for native discovery AND have `lua/zx0r/lsp/` for `require()` access — but
> that's duplication.
>
> **Decision:** Keep `lsp/` at root (Neovim convention for `vim.lsp.enable()`), but update AGENTS.md
> to document this is intentional RTP behavior, NOT a violation.

---

## Phase 3: colors/ Cleanup

### 3.1 Current State

- `colors/environment-x.lua` — 1028-line colorscheme engine ✅ (correct location)
- `colors/syntax/*.lua` — 21 per-filetype syntax themes ⚠️ (pollutes `:colorscheme` autocomplete)

### 3.2 Solution: Thin Proxy Pattern

Keep thin proxy files in `colors/syntax/` for RTP discovery, move implementation to
`lua/zx0r/theme/syntax/`:

```lua
-- colors/syntax/cyberpunk_glow.lua (PROXY — 2 lines)
vim.g.colors_name = "syntax/cyberpunk_glow"
require("zx0r.theme.syntax.cyberpunk_glow")
```

```lua
-- lua/zx0r/theme/syntax/cyberpunk_glow.lua (IMPLEMENTATION)
local set_hl = vim.api.nvim_set_hl
-- ... all highlight definitions
```

---

## Phase 4: Anti-Pattern Audit & Fixes

### 4.1 Detected Anti-Patterns

| #   | Anti-Pattern                       | Location              | Fix                                                                                                                                   |
| --- | ---------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **GC API misuse**                  | `perf.lua:52`         | `collectgarbage("incremental", {...})` is invalid LuaJIT. Use `collectgarbage("setpause", 150)` + `collectgarbage("setstepmul", 300)` |
| 2   | **Sync `vim.uv.fs_stat`**          | `guard.lua:21`        | Acceptable in `BufReadPre` (one-shot). Document as intentional.                                                                       |
| 3   | **Sync `vim.fs.find`**             | `quality.lua`         | Acceptable per-lint. Cache per-workspace recommended.                                                                                 |
| 4   | **`vim.fn.col`/`vim.fn.indent`**   | `keymaps.lua:118-120` | Acceptable (keymap, not hot path).                                                                                                    |
| 5   | **Missing branch/diff in lualine** | `ui.lua:1482-1483`    | Branch and diff are commented out. Uncomment for Principal-grade telemetry.                                                           |

### 4.2 perf.lua GC Fix

```lua
-- BEFORE (broken):
pcall(collectgarbage, "incremental", { pause = 150, stepmul = 300 })

-- AFTER (correct LuaJIT API):
collectgarbage("setpause", 150)
collectgarbage("setstepmul", 300)
```

---

## Phase 5: UI Modernization — DEFCON Cyberpunk Aesthetic

### 5.1 Diagnostic Icons (Modern Nerd Font v3)

```lua
-- BEFORE:
{ ERROR = "󰅚 ", WARN = "󰀪 ", HINT = "", INFO = "󰋽 " }

-- AFTER (sharper, more cyberpunk):
{ ERROR = " ", WARN = " ", HINT = "󰌶 ", INFO = " " }
```

### 5.2 Mode Icons (Cyberpunk Terminal Aesthetic)

Already excellent. Keep current implementation.

### 5.3 Lualine: Re-enable Branch + Diff

```lua
lualine_b = {
  branch,
  diff,
},
```

### 5.4 Notifier Glass Effect

```lua
styles = {
  notification = {
    border = "rounded",
    zindex = 100,
    wo = { winblend = 5 }, -- Subtle cyberpunk glass depth
  },
},
```

---

## Execution Order

| Step | Action                                        | Risk   | SLA Impact                             |
| ---- | --------------------------------------------- | ------ | -------------------------------------- |
| 1    | Fix `perf.lua` GC API                         | None   | Correct GC tuning                      |
| 2    | Create `lua/zx0r/` directory structure        | Low    | None                                   |
| 3    | Move all `lua/core/` → `lua/zx0r/core/`       | Medium | Requires all require paths updated     |
| 4    | Move all `lua/plugins/` → `lua/zx0r/plugins/` | Medium | Requires lazy.nvim import path updated |
| 5    | Update `init.lua` require paths               | Low    | None                                   |
| 6    | Update `core/lazy.lua` import path            | Low    | None                                   |
| 7    | Update all internal cross-references          | Medium | None                                   |
| 8    | Move syntax themes + create proxies           | Low    | None                                   |
| 9    | UI modernization across all modules           | Low    | None                                   |
| 10   | Update AGENTS.md                              | Low    | None                                   |
| 11   | Create ANTI_PATTERNS.md                       | None   | Documentation                          |
| 12   | Quality Gates verification                    | None   | Validation                             |

---

## Quality Gates (Post-Implementation)

```bash
# Gate 1: Clean headless exit
env NVIM_APPNAME=x0r nvim --headless +qa

# Gate 2: Core Doctor (after namespace migration)
env NVIM_APPNAME=x0r nvim --headless \
  -c "lua require('zx0r.core.audit.doctor').run(); vim.wait(1000, function() return false end)" +qa

# Gate 3: Full benchmark
python3 x0r/scripts/benchmark.py
```
