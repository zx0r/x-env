# x0r/nvim — Forensic Audit & Remediation Plan

> **Epoch:** September 2026 | **Auditor:** Antigravity Principal Architect  
> **Target:** `~/.config/nvim/x0r/` | **Reference:** `x0r_old/`  
> **Goal:** Zero Overhead · Zero SLA Violation · Maximum Performance · Best UX/UI · Best Architectural Patterns

---

## Table of Contents

1. [System Topology & SOLID Dependency Diagram](#1-system-topology)
2. [Forensic Audit Findings (by Severity)](#2-forensic-audit-findings)
3. [7-Domain Comparative Trade-Off Matrix](#3-7-domain-matrix)
4. [Structured Remediation Plan](#4-remediation-plan)
5. [Migration from x0r_old — Best Patterns](#5-migration-from-x0r_old)
6. [CI/CD Oracle Script Specification](#6-cicd-oracle)
7. [Popperian Assumptions & Falsifiability Table](#7-falsifiability-table)

---

## 1. System Topology

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        macOS Darwin (Apple Silicon / Metal)                          │
│                                                                                     │
│  ┌──────────────────────┐     Unix Domain Socket (0600)     ┌────────────────────┐  │
│  │  Kitty GPU Terminal  │◄─────── IPC / OSC 52 ───────────►│   tmux (escape=0)  │  │
│  │  Metal/Cocoa Render  │     repaint_delay ≤ 10ms          │   focus-events on  │  │
│  │  ProMotion 120Hz     │     input_delay ≤ 1ms             │   extended-keys on │  │
│  └──────────┬───────────┘                                   └─────────┬──────────┘  │
│             │ PTY / VT100 + Undercurl (Smulx)                         │             │
│             └─────────────────────┬───────────────────────────────────┘             │
│                                   │                                                 │
│  ┌────────────────────────────────▼──────────────────────────────────────────────┐  │
│  │                          Neovim 0.12+ (LuaJIT 2.1)                            │  │
│  │                                                                               │  │
│  │  ┌────────────────────────────────────────────────────────────────────────┐   │  │
│  │  │ Φ_boot: vim.loader → providers → GC tune → shada defer → options     │   │  │
│  │  └────────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                               │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────────┐  ┌────────────────────┐ │  │
│  │  │  core/       │  │  lsp/       │  │  plugins/     │  │  llmops/           │ │  │
│  │  │  options     │  │  init       │  │  themes/      │  │  agent_bridge      │ │  │
│  │  │  keymaps     │  │  handlers   │  │  completion   │  │  context_filter    │ │  │
│  │  │  autocmds    │  │  diagnostics│  │  treesitter   │  │  mcp_client        │ │  │
│  │  │  perf        │  │  attach     │  │  picker       │  │  keychain_secret   │ │  │
│  │  │  security    │  │             │  │  explorer     │  │                    │ │  │
│  │  └──────┬───────┘  └──────┬──────┘  │  navigation   │  └─────────┬──────────┘ │  │
│  │         │                 │         │  vcs, dap     │            │            │  │
│  │         │ NEVER imports ──┼────────►│  ai, terminal │            │            │  │
│  │         │ from plugins/   │         │  formatting   │   vim.system (async)   │  │
│  │         │                 │         └──────┬────────┘   vim.uv.spawn         │  │
│  │         │                 │                │            SIGTERM cleanup       │  │
│  │         └─────────────────┴────────────────┴────────────┘                    │  │
│  │                                                                               │  │
│  │  ┌────────────────────────────────────────────────────────────────────────┐   │  │
│  │  │ lib/guard · lib/bench · lib/telemetry · lib/secops · lib/health      │   │  │
│  │  └────────────────────────────────────────────────────────────────────────┘   │  │
│  │                                                                               │  │
│  │  ┌────────────────────────────────────────────────────────────────────────┐   │  │
│  │  │ roles/ (architect · scientist · platform · datascience)               │   │  │
│  │  └────────────────────────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐│
│  │  macOS Keychain (security find-generic-password) → Ephemeral Secret Retrieval   ││
│  └─────────────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Forensic Audit Findings

### CRITICAL (Block Shipping)

| # | File | Line | Finding | OPUS Domain |
|---|------|------|---------|-------------|
| C1 | `core/autocmds.lua` | 119 | **SOLID/DIP Violation:** `core/` requires `mcphub` (a plugin). Core layer must NEVER import from plugins. Move MCP cleanup to `llmops/` or to a `User` autocmd in `plugins/ai.lua`. | D1 |
| C2 | `core/autocmds.lua` | 155–157 | **SOLID/SRP Violation:** `autocmds.lua` ends with `require("lib.bench")`, `require("lib.telemetry").setup()`, `require("lib.secops")` — these are library initializations that belong in `init.lua`, not inside autocmds. Autocmds module should contain ONLY autocmd definitions. | D1 |
| C3 | `init.lua` | 8 | **vim.loader.enable() is NOT line 1 of init.lua.** It's inside `core/perf.lua` which is loaded via `require("core.perf")`. While functionally equivalent, the OPUS spec demands it as the absolute first instruction. Move `vim.loader.enable()` to line 1 of `init.lua` itself. | D2 |
| C4 | — | — | **Missing `lua/lsp/` layer.** LSP orchestration is embedded inside `plugins/lsp.lua` (286 lines). Per OPUS, LSP must be a standalone orthogonal layer decoupled from plugin specs. | D1 |
| C5 | — | — | **Missing `lua/llmops/` layer.** No dedicated AI/MCP orchestration layer exists. Agent bridge, context sanitizer, and keychain secret retrieval are absent. | D6 |
| C6 | — | — | **Missing `core/security.lua`.** No `modelineexpr = false` hardening, no `vim.secure.read` for `exrc`, no filesystem permission enforcement at startup. | D7 |

### HIGH (Degraded Performance / Architecture)

| # | File | Line | Finding | OPUS Domain |
|---|------|------|---------|-------------|
| H1 | `plugins/lsp.lua` | 72 | `vim.api.nvim_get_runtime_file("", true)` returns ALL runtime files — expensive call that can take 10–50ms. Should use `{ vim.env.VIMRUNTIME }` for lua_ls workspace library. | D2 |
| H2 | `plugins/treesitter.lua` | 8 | `lazy = false` — Treesitter is eagerly loaded, adding to startup time. Should use `event = "BufReadPost"` or `"FileType"` trigger. | D2 |
| H3 | `plugins/ui.lua` | 12 | `snacks.nvim` has `lazy = false` — entire mega-plugin loaded eagerly. This is the single largest startup contributor. Evaluate which snacks modules truly need eager load. | D2 |
| H4 | `plugins/lualine.lua` | — | **Missing lazy loading.** Lualine has no `event`, `keys`, or `cmd` trigger. It loads eagerly. Should be `event = "UIEnter"`. | D2 |
| H5 | `plugins/lualine.lua` | — | **Missing diagnostics, diff, LSP info sections.** Bare-minimum statusline. Missing: diff counts, diagnostics, LSP client name, macro recording, search count, file size, attached formatters. | D5 |
| H6 | `plugins/terminal.lua` | 9 | `vim-tmux-navigator` is VimL, not Lua. Replace with `smart-splits.nvim` (Lua, also handles Kitty+WezTerm, resize support). | D4 |
| H7 | `core/keymaps.lua` | 20–56 | `focus_left()` / `focus_right()` iterate all windows and check filetypes — O(n) on every keypress. With smart-splits.nvim this becomes a single function call. | D2 |
| H8 | — | — | **Missing `.aiignore` file.** No context filtering for LLM prompts. Sensitive files (`.env`, `*.pem`, credentials) could be sent to AI agents. | D6 |
| H9 | `lib/telemetry.lua` | 48–57 | **Monkey-patching `vim.lsp.buf_request`.** This global override is fragile and may break with Neovim API changes. Use `LspRequest` autocmd or a proper client handler wrapper. | D5 |
| H10 | `core/options.lua` | 76–81 | **Autocmd inside options.lua.** The `UIEnter` clipboard deferred setup violates the "NO autocmds" rule stated in the module header. Move to `autocmds.lua`. | D1 |

### MEDIUM (Suboptimal / Missing Best Practices)

| # | File | Line | Finding | OPUS Domain |
|---|------|------|---------|-------------|
| M1 | `plugins/ai.lua` | 117 | Synchronous `:wait()` in commit prompt generator. Acceptable for user-triggered action but should be documented as cold-path-only. | D2 |
| M2 | `lib/secops.lua` | 25, 35 | Synchronous `:wait()` calls in audit functions. Acceptable for on-demand commands but should be marked. | D7 |
| M3 | `plugins/explorer.lua` | 6–8 | `neo-tree` depends on `plenary.nvim` + `nui.nvim` + `nvim-web-devicons` — three runtime deps. `nvim-web-devicons` is redundant given `mini.icons` with mock in `ui.lua`. Remove `nvim-web-devicons` dep. | D2 |
| M4 | `plugins/navigation.lua` | 24–27 | `harpoon2` depends on `plenary.nvim` which is the legacy dependency model. Evaluate if newer harpoon releases dropped plenary. Also branch pinning (`harpoon2`) rather than SHA. | D7 |
| M5 | `plugins/vcs.lua` | 129–140 | `git-worktree.nvim` calls `fzf-lua.git_worktrees()` which may not exist as a native fzf-lua provider. Verify compatibility. | D5 |
| M6 | `plugins/lualine.lua` | 4 | Depends on `nvim-web-devicons` instead of `mini.icons`. Inconsistent with the `mini.icons` mock established in `ui.lua`. | D1 |
| M7 | `lazy-lock.json` | — | All 59 plugins properly pinned to 40-char SHAs. However, `noice.nvim` is in the lockfile but NOT referenced in any plugin spec — ghost dependency. | D7 |
| M8 | `lazy-lock.json` | — | `image.nvim`, `otter.nvim`, `quarto-nvim`, `molten-nvim` are locked but only loaded via roles. Verify they don't add startup overhead when inactive. | D2 |
| M9 | — | — | **Missing LuaCATS annotations** across all modules. No `---@class`, `---@field`, `---@param`, `---@return` on any function in `core/`, `lib/`, `plugins/`. | D1 |
| M10 | — | — | **No `selene.toml`** in the project root. CI workflow checks for it but it doesn't exist, so selene lint is always skipped. | D8 |
| M11 | `core/autocmds.lua` | 45–67 | Trim whitespace on save iterates ALL buffer lines. For large files this is O(n). Should be skipped if `conform.nvim` trim_whitespace formatter handles it already. | D2 |
| M12 | `plugins/picker.lua` | 142 | `fzf-lua` also registers as `vim.ui.select` — conflicts with `snacks.picker` which sets `ui_select = true`. Only one should own `vim.ui.select`. | D5 |

### LOW (Polish / Ergonomics)

| # | File | Line | Finding | OPUS Domain |
|---|------|------|---------|-------------|
| L1 | `core/keymaps.lua` | 7 | `maplocalleader = " "` — same as `mapleader`. Should be `","` or `"\\"` for proper filetype-specific mappings. | D5 |
| L2 | `core/options.lua` | 30 | `cmdheight = 0` without `noice.nvim` may cause message display issues. noice.nvim IS in lockfile — verify it's actually loaded. | D5 |
| L3 | `plugins/diagnostics.lua` | 63 | `tiny-inline-diagnostic` disables native `virtual_text` but `lsp.lua` line 223 enables it. Config conflict — whichever loads last wins. | D5 |
| L4 | `benchmark.py` | — | Python-based benchmark script instead of POSIX/Bash per OPUS spec. Replace with shell script for portability. | D8 |
| L5 | — | — | No `ftplugin/` for TypeScript, Markdown, Nix, Terraform, Bash — only Python, Rust, Go have ftplugin files. | D5 |

---

## 3. 7-Domain Comparative Trade-Off Matrix (September 2026)

### Domain 1: Clean Architecture & SOLID Design

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| Layer isolation | core → plugins leak (C1, C2) | Strict core → lsp → plugins → llmops | Refactor |
| Interface contracts | None | LuaCATS annotations on all public APIs | Add |
| Event bus | Raw autocmds | `User` events + `LspAttach` patterns | Refactor |
| DIP compliance | core/ imports mcphub | core/ imports nothing from plugins/ | Fix |

### Domain 2: Core Runtime & Startup SLA

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| vim.loader | In perf.lua (line 9) | Line 1 of init.lua | Move |
| Startup target | ~15-25ms estimated | ≤ 15ms headless, ≤ 20ms UI | Optimize |
| Treesitter loading | `lazy = false` | Event-driven | Fix |
| snacks.nvim | `lazy = false` (entire plugin) | Split: eager notifier only, rest lazy | Refactor |
| lualine | No lazy trigger | `event = "UIEnter"` | Fix |

### Domain 3: Kitty GPU & Metal Optimization

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| kitty.conf | Not in x0r/ config | Audited, hardened, committed | Create |
| repaint_delay | Unknown | ≤ 10ms | Configure |
| input_delay | Unknown | ≤ 1ms | Configure |
| allow_remote_control | Unknown | `socket-only` or `no` | Harden |
| Nerd Font symbol_map | Unknown | Explicit mapping | Configure |

### Domain 4: Tmux Low-Latency IPC

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| tmux.conf | Not in x0r/ config | Audited, hardened, committed | Create |
| escape-time | Unknown | 0 | Enforce |
| focus-events | Unknown | on | Enforce |
| Navigation plugin | vim-tmux-navigator (VimL) | smart-splits.nvim (Lua, Kitty+Tmux) | Replace |
| Status bar budget | Unknown | < 3.5ms per refresh | Enforce |

### Domain 5: Semantic Code Intelligence

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| Completion | blink.cmp (Rust) ✓ | Already optimal | Keep |
| Picker | fzf-lua ✓ | Already optimal | Keep |
| LSP UX | Basic attach + inlay hints | + glance.nvim, actions-preview, inc-rename, lightbulb | Add |
| Diagnostics | tiny-inline-diagnostic ✓ | Already good, fix config conflict with lsp.lua | Fix |

### Domain 6: Agentic AI / LLMOps

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| llmops/ layer | Missing | Full async agent bridge + context filter | Create |
| .aiignore | Missing | Exclude secrets, binaries, lockfiles | Create |
| Secret retrieval | ENV vars only | macOS Keychain via async vim.system | Add |
| MCP cleanup | In core/autocmds.lua | In llmops/ or plugins/ai.lua | Move |

### Domain 7: DevSecOps Hardening

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| core/security.lua | Missing | modelineexpr=false, exrc guard, perms | Create |
| API key scanning | In lib/secops.lua (basic) | Comprehensive CI gate | Enhance |
| lockfile integrity | All SHAs pinned ✓ | Already compliant | Keep |
| Ghost deps | noice.nvim in lockfile | Remove or add spec | Fix |

### Domain 8: CI/CD Benchmarking

| Aspect | Current State | Target State | Action |
|--------|--------------|--------------|--------|
| Benchmark script | Python (benchmark.py) | POSIX/Bash oracle + Python | Add Bash |
| Scoring | Basic JSON | 0-100 scored 6-gate system | Implement |
| selene.toml | Missing | Create with vim globals | Create |
| Kitty/Tmux audit | Not in CI | Added as Gates 4 & 5 | Add |

---

## 4. Structured Remediation Plan

### Phase 1: Architecture (CRITICAL fixes)

> **Estimated effort:** 2 hours  
> **Impact:** Fixes all SOLID violations, establishes missing layers

#### 1.1 Move `vim.loader.enable()` to line 1 of `init.lua` [C3]

```lua
-- init.lua line 1 — MUST be absolute first instruction
vim.loader.enable()
require("core.perf")  -- GC tuning, providers, shada defer (no longer needs loader)
```

Remove `vim.loader.enable()` from `core/perf.lua`.

#### 1.2 Extract lib requires from `core/autocmds.lua` [C2]

Remove lines 155–157 from `autocmds.lua`. Move them to `init.lua`:

```lua
-- init.lua (after core.autocmds)
require("lib.bench")
require("lib.telemetry").setup()
require("lib.secops")
```

#### 1.3 Remove mcphub dependency from `core/autocmds.lua` [C1]

Move the `VimLeavePre` MCP cleanup autocmd to `plugins/ai.lua` as part of mcphub's config:

```lua
-- In plugins/ai.lua, mcphub config function:
config = function(_, opts)
  require("mcphub").setup(opts)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("llmops_mcp_cleanup", { clear = true }),
    callback = function()
      local ok, hub = pcall(require, "mcphub")
      if ok and hub.stop_all then hub.stop_all() end
    end,
  })
end,
```

#### 1.4 Create `lua/lsp/init.lua` layer [C4]

Extract from `plugins/lsp.lua`:
- `on_attach` handler → `lua/lsp/attach.lua`
- `capabilities` builder → `lua/lsp/capabilities.lua`
- Diagnostic config → `lua/lsp/diagnostics.lua`
- Server configs → stays in `plugins/lsp.lua` but imports from `lsp/`

#### 1.5 Create `lua/llmops/` layer [C5]

New files:
- `lua/llmops/agent_bridge.lua` — Async agent runner with timeout, SIGTERM, cancellation
- `lua/llmops/context_filter.lua` — `.aiignore` parser and context sanitizer
- `lua/llmops/keychain.lua` — macOS Keychain secret retrieval via async `vim.system`

#### 1.6 Create `lua/core/security.lua` [C6]

```lua
-- core/security.lua
vim.o.modelineexpr = false
vim.o.modeline = false  -- Or keep true with expr=false
vim.o.exrc = false       -- Disable unless vim.secure.read is used
-- Enforce config directory permissions at startup
```

#### 1.7 Move clipboard autocmd from `options.lua` to `autocmds.lua` [H10]

---

### Phase 2: Performance (HIGH fixes)

> **Estimated effort:** 1.5 hours  
> **Impact:** Reduces startup by 30-50%

#### 2.1 Fix lua_ls workspace library [H1]

```lua
workspace = {
  checkThirdParty = false,
  library = { vim.env.VIMRUNTIME },  -- NOT nvim_get_runtime_file("", true)
},
```

#### 2.2 Lazy-load Treesitter [H2]

```lua
{
  "nvim-treesitter/nvim-treesitter",
  event = { "BufReadPost", "BufNewFile" },  -- NOT lazy = false
  build = ":TSUpdate",
  ...
}
```

#### 2.3 Optimize snacks.nvim loading [H3]

Keep `lazy = false` only for the notifier (which replaces `vim.notify`). All other snacks modules are already lazily activated. The `priority = 1000` ensures it loads before themes. Acceptable tradeoff — document this decision.

#### 2.4 Add lazy trigger to lualine [H4]

```lua
{
  "nvim-lualine/lualine.nvim",
  event = "UIEnter",
  dependencies = { "echasnovski/mini.icons" },  -- NOT nvim-web-devicons
  ...
}
```

#### 2.5 Replace vim-tmux-navigator with smart-splits.nvim [H6]

```lua
{
  "mrjones2014/smart-splits.nvim",
  event = "VeryLazy",
  opts = {
    at_edge = "stop",
    cursor_follows_swapped_bufs = true,
    resize_mode = { hooks = { on_leave = function() end } },
  },
  keys = {
    { "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move left" },
    { "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move down" },
    { "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move up" },
    { "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move right" },
    { "<A-h>", function() require("smart-splits").resize_left() end, desc = "Resize left" },
    { "<A-j>", function() require("smart-splits").resize_down() end, desc = "Resize down" },
    { "<A-k>", function() require("smart-splits").resize_up() end, desc = "Resize up" },
    { "<A-l>", function() require("smart-splits").resize_right() end, desc = "Resize right" },
  },
}
```

This replaces `vim-tmux-navigator` AND the manual `focus_left()`/`focus_right()` functions in `keymaps.lua`.

#### 2.6 Remove duplicate whitespace trimming [M11]

`conform.nvim` already has `["_"] = { "trim_whitespace", "trim_newlines" }`. The `BufWritePre` autocmd in `autocmds.lua` (lines 47–67) is redundant. Remove it.

#### 2.7 Fix `vim.ui.select` conflict [M12]

Remove `require("fzf-lua").register_ui_select()` from `picker.lua` since `snacks.picker` already sets `ui_select = true`. One owner only.

---

### Phase 3: Security & DevSecOps (HIGH/MEDIUM fixes)

> **Estimated effort:** 1 hour

#### 3.1 Create `.aiignore` [H8]

```
# .aiignore — Context filter for LLM agents
*.pem
*.key
*.p12
*.pfx
.env*
!.env.example
*.secret
credentials*
lazy-lock.json
.git/
node_modules/
__pycache__/
*.pyc
.venv/
target/
```

#### 3.2 Clean ghost dependencies [M7]

Remove `noice.nvim` from lockfile (or add a spec if it's needed). Same for `image.nvim`, `otter.nvim`, `quarto-nvim`, `molten-nvim` — verify these are actually loaded by roles.

#### 3.3 Create `selene.toml` [M10]

```toml
std = "vim"

[config]
property_access_in_strings = "allow"
```

#### 3.4 Fix diagnostic config conflict [L3]

`lsp.lua` sets `virtual_text = { enabled = true }`, then `diagnostics.lua` sets `virtual_text = false`. Solution: remove `virtual_text` config from `lsp.lua` entirely — let `tiny-inline-diagnostic` own it.

---

### Phase 4: UX/DX Enhancement (Migrations from x0r_old)

> **Estimated effort:** 2 hours

#### 4.1 MUST-HAVE Migrations

| Plugin | Purpose | x0r_old Source | Priority |
|--------|---------|---------------|----------|
| `mrjones2014/smart-splits.nvim` | Kitty+Tmux split navigation + resize | `extras/util/smart-splits.lua` | ★★★ |
| `mikesmithgh/kitty-scrollback.nvim` | Kitty scrollback buffer in Neovim | `extras/util/kitty-scrollback.lua` | ★★★ |
| `dnlhc/glance.nvim` | Windowed LSP peek (definitions/refs) | `extras/lsp/glance.lua` | ★★★ |
| `aznhe21/actions-preview.nvim` | Preview code actions before applying | `extras/lsp/actions-preview.lua` | ★★★ |

#### 4.2 SHOULD-HAVE Migrations

| Plugin | Purpose | x0r_old Source | Priority |
|--------|---------|---------------|----------|
| `smjonas/inc-rename.nvim` | Incremental LSP rename with preview | `extras/lsp/inc-rename.lua` | ★★ |
| `Wansmer/symbol-usage.nvim` | Inline reference/implementation counts | `extras/lsp/symbol-usage.lua` | ★★ |
| `kosayoda/nvim-lightbulb` | Code action availability indicator | `extras/lsp/lightbulb.lua` | ★★ |
| `smoka7/multicursors.nvim` | Multi-cursor editing | `extras/coding/multicursor.lua` | ★★ |
| `laytan/cloak.nvim` | Mask sensitive values in .env files | `extras/util/cloak.lua` | ★★ |
| `Saecki/crates.nvim` | Cargo.toml dependency management | (new, not in old) | ★★ |

#### 4.3 NICE-TO-HAVE Migrations

| Plugin | Purpose |
|--------|---------|
| `max397574/better-escape.nvim` | Fast jk/jj escape without delay |
| `VidocqH/lsp-lens.nvim` | Code lens display |

---

### Phase 5: Lualine Overhaul [H5]

Replace the bare statusline with a high-density information display:

```lua
sections = {
  lualine_a = { { "mode", fmt = function(s) return s:sub(1,3) end } },
  lualine_b = {
    "branch",
    { "diff", symbols = { added = " ", modified = " ", removed = " " } },
  },
  lualine_c = {
    { "filename", path = 1, symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" } },
    {
      "diagnostics",
      sources = { "nvim_diagnostic" },
      symbols = { error = " ", warn = " ", info = " ", hint = "󰠠 " },
    },
  },
  lualine_x = {
    -- Macro recording indicator
    { function() local reg = vim.fn.reg_recording(); return reg ~= "" and "● REC @" .. reg or "" end },
    -- Search count
    { "searchcount", maxcount = 999, timeout = 500 },
    -- LSP client name
    { function()
        local clients = vim.lsp.get_clients({ bufnr = 0 })
        if #clients == 0 then return "" end
        return " " .. clients[1].name
    end },
    "filetype",
  },
  lualine_y = { "progress" },
  lualine_z = { "location" },
},
```

---

## 5. Migration from x0r_old

### Best Patterns Extracted

1. **Smart-splits integration pattern** — Handles Kitty AND Tmux pane boundaries with a single Lua plugin. Eliminates VimL dependency and manual window iteration.

2. **Kitty-scrollback** — Opens kitty terminal scrollback as a Neovim buffer. Zero-cost (loads only when kitty sends the signal).

3. **Glance.nvim peek pattern** — Non-disruptive LSP navigation. User sees definition/references in a floating window without context switch.

4. **Actions-preview** — Shows diff preview before applying code actions. Eliminates "oops, wrong action" mistakes.

5. **Cloak.nvim** — Automatically masks `.env` values. Security at the display layer, not just at the process layer.

6. **Extended language configs** — `rust-extended.lua` had crates.nvim; `python-extended.lua` had DAP test integration; `go-extended.lua` had gopher.nvim.

### Patterns to AVOID (from x0r_old)

1. **LazyVim extras import pattern** — Deeply nested `extras/` hierarchy adds indirection. Flat domain modules are cleaner.
2. **Colorscheme proliferation** — 40+ colorscheme files. Keep ≤ 3 themes.
3. **nvim-web-devicons everywhere** — Use `mini.icons` mock consistently.
4. **plenary.nvim as universal dependency** — Moving toward native `vim.system` / `vim.uv` eliminates this.

---

## 6. CI/CD Oracle Script Specification

### Script: `scripts/workstation_audit_oracle.sh`

**6 Gates, 100 Points Total, POSIX/Bash, Deterministic Scoring**

| Gate | Points | What It Tests |
|------|--------|---------------|
| G1: Startup SLA | 20 | 10× headless nvim --startuptime, mean ≤ 20ms |
| G2: SOLID Architecture | 20 | core/ zero-imports from plugins/, vim.loader line 1, defaults.lazy=true, no sync shell calls |
| G3: DevSecOps | 20 | lazy-lock.json pinned SHAs, modelineexpr=false, permissions 0700/0600, no leaked secrets |
| G4: Kitty GPU Security | 15 | repaint_delay ≤ 10, input_delay ≤ 1, allow_remote_control ∈ {no, socket-only} |
| G5: Tmux Low-Latency | 15 | escape-time 0, focus-events on, socket permissions 0700 |
| G6: LLMOps Hygiene | 10 | llmops/ uses vim.system/vim.uv only, no tokens in show-environment |

**Pass threshold: ≥ 95/100**

See the generated script in Phase 6 below.

---

## 7. Popperian Assumptions & Falsifiability Table

| Decision | Governing Principle | Falsification Metric | Oracle Command |
|----------|--------------------|--------------------|----------------|
| vim.loader.enable() as first instruction | LuaJIT bytecode cache eliminates glob I/O | Startup time ≤ 20ms fails after removal | `grep -n "vim.loader" init.lua \| head -1` must return line 1 |
| defaults.lazy = true | Plugins not needed at boot should not be loaded | Plugin count at startup > 5 | `nvim --headless -c 'lua print(require("lazy").stats().loaded)' -c qa` |
| escape-time 0 in tmux | Zero escape interpretation delay for Neovim | Keystroke latency > 50ms | `tmux show -g escape-time` must return 0 |
| Rust fuzzy backend (blink.cmp) | SIMD string matching is faster than Lua | Completion popup > 50ms | Telemetry P90 from `:CoreTelemetry` |
| core/ never imports plugins/ | SOLID DIP — high-level modules don't depend on low-level | `rg "require.*plugins" lua/core/` returns matches | Gate G2 static scan |
| No plaintext secrets | Supply-chain security principle | `rg "sk-ant-\|sk-proj-\|API_KEY=" lua/` returns matches | Gate G3 secret scan |
| Async-only in llmops/ | Main-thread blocking degrades UX | `rg "vim.fn.system\|io.popen\|:wait()" lua/llmops/` returns matches | Gate G6 async scan |
| ≤ 3 themes | Fewer themes = faster color computation | Theme count > 3 in plugins/themes/ | `ls lua/plugins/themes/ \| wc -l` |

---

## Implementation Priority Order

```
Phase 1 → C1, C2, C3, C4, C5, C6, H10     (Architecture — MUST DO FIRST)
Phase 2 → H1, H2, H4, H5, H6, H7, M11, M12 (Performance — Immediate measurable gain)
Phase 3 → H8, M7, M10, L3                   (Security & DevSecOps)
Phase 4 → Migrations from x0r_old            (UX Enhancement)
Phase 5 → CI/CD Oracle Script                (Verification Harness)
Phase 6 → LuaCATS annotations everywhere     (Type safety & documentation)
```
