# AGENTS.md — x0r/nvim Context & Architectural Specification

> **Audience:** Autonomous AI Agents (Antigravity, Cursor, Claude Code, Copilot Workspace)  
> **Persona Required:** Lead Scientist, Principal Systems Architect & Senior UX/UI Engineer  
> **Runtime Baseline:** Neovim $\ge 0.12.0$ (macOS arm64 / Linux x86_64)  
> **Repository Path:** `/Users/x0r/.config/nvim` (`NVIM_APPNAME=x0r`)  
> **Architectural Paradigm:** Capability-Oriented Domain Decomposition (CODA), Zero-Overhead Contract, Domain-Driven Design (DDD)

---

## 1. Executive Summary & The Zero-Overhead Contract

`x0r/nvim` is an enterprise-grade, deterministic Neovim development environment engineered to immutable performance and security standards. 

When modifying, auditing, or adding code to this repository, you **MUST** uphold the following **Zero-Overhead Contract**:

1. **Zero Synchronous Shell I/O in Hot Paths:** Never call `vim.fn.system()`, `io.popen()`, `os.execute()`, or `vim.fn.systemlist()` inside startup paths, autocommands, or UI loops. Always use asynchronous `vim.system()`, `vim.uv.spawn()`, or pure `vim.uv.fs_*` operations.
2. **Zero Idle Polling Timers:** Never create persistent recurring timers on the libuv event loop (e.g. `vim.uv.new_timer():start(0, 100, ...)`). All background observation must be event-driven or synthetic on-demand.
3. **Bounded Startup SLA:** Headless cold start must remain $< 20.0\text{ ms}$ (empirical observed: $18 - 24\text{ ms}$). Memory baseline $< 60.0\text{ MB}$ (empirical observed: $\sim 18\text{ MB}$).
4. **Deterministic Large-File Protection:** 100% of buffers $> 1\text{MB}$ must disengage AST parsers, LSP, and heavy syntax engines before UI attachment via [`x0r/lua/core/guard.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/guard.lua).
5. **Clean Bounded Contexts (No "Junk Drawers"):** Folders named `lib/`, `utils/`, or `helpers/` are strictly forbidden. Runtime governors live in `core/`; on-demand audit and quality tooling lives in `core/audit/`; capability plugins live in `plugins/`.

---

## 2. Service Level Agreements (SLA) & Invariant Matrix

The configuration enforces 7 machine-verifiable SLAs validated via [`x0r/scripts/benchmark.py`](file:///Users/x0r/.config/nvim/x0r/scripts/benchmark.py) and in-process via [`:CoreDoctor`](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/doctor.lua):

| Metric | Target SLA | Empirical Observed | Verification Mechanism |
| :--- | :--- | :--- | :--- |
| **Headless Cold Start** | $< 20.0\text{ ms}$ | **$18.4 - 24.2\text{ ms}$** | `vim.loader` bytecode cache + remote provider suppression |
| **UI Frame Redraw Latency** | $< 2.0\text{ ms}$ | **$0.02 - 0.04\text{ ms}$** | Pure asynchronous I/O, `format_after_save` non-blocking formatter |
| **AST Parse Latency** | $< 5.0\text{ ms}$ | **$0.17 - 0.20\text{ ms}$** | Incremental C-parsers, deferred fold expressions |
| **Idle Polling Timers** | **0 active** | **0 active** | Graph walk via `vim.uv.walk()` rejects repeating timers |
| **Synchronous Shell Calls** | **0 calls** | **0 calls** | Static AST ripgrep scanner across all `lua/` files |
| **Memory Footprint** | $< 60.0\text{ MB}$ | **$18.4\text{ MB}$** | LuaJIT GC pacing (`collectgarbage("setpause", 150)`, `setstepmul, 300`) |
| **Large File Protection** | **100% guarded** | **Tier 1 (>1MB) / Tier 2 (>10MB)** | `BufReadPre` trigger via [`core.guard`](file:///Users/x0r/.config/nvim/x0r/lua/core/guard.lua) before parser attachment |

---

## 3. Repository Topology & Bounded Contexts

```text
x0r/
├── init.lua                          # Deterministic bootstrap entrypoint
├── lazy-lock.json                    # Immutable supply-chain commit lockfile
│
├── lua/
│   ├── core/                         # Core Runtime Subsystem (Always active)
│   │   ├── perf.lua                  # vim.loader, remote provider elimination, GC tuning
│   │   ├── guard.lua                 # Multi-tier large file runtime governor (libuv fs_stat)
│   │   ├── options.lua               # Pure state mutation (vim.opt / vim.o) — zero side-effects
│   │   ├── keymaps.lua               # Global ergonomic bindings & leader initialization
│   │   ├── lazy.lua                  # Lazy.nvim bootstrap with clean missing=true installer
│   │   ├── autocmds.lua              # Augroup-isolated lifecycle events & filetype triggers
│   │   │
│   │   └── audit/                    # Zero-Overhead Quality & Observability Subsystem (On-demand)
│   │       ├── init.lua              # Lazy command router (:CoreDoctor, :CoreBenchmark, etc.)
│   │       ├── doctor.lua            # 7-invariant SLA engine, :checkhealth provider & buffer secret scan
│   │       └── benchmark.lua         # Hyperfine cold-start, startuptime profiling & synthetic frame latency
│   │
│   └── plugins/                      # Capability-Oriented Domain Manifests (Flat 23-Domain Composition)
│       ├── language.lua              # Semantic intelligence: LSP, mason, capabilities
│       ├── syntax.lua                # AST & structural syntax (Treesitter, text-objects)
│       ├── coding.lua                # Completion (blink.cmp), formatting (conform.nvim), pairs
│       ├── diagnostics.lua           # Diagnostic aggregation, routing, and presentation
│       ├── quality.lua               # Static analysis, linters (nvim-lint), code metrics
│       ├── debugging.lua             # Runtime debugging, DAP adapters, breakpoint UI
│       ├── testing.lua               # Test discovery, runner isolation (neotest)
│       ├── navigation.lua            # Fuzzy discovery (snacks.picker), hops (flash.nvim)
│       ├── workspace.lua             # Project context, session persistence, root discovery
│       ├── explorer.lua              # Spatial filesystem interface (oil.nvim, neo-tree)
│       ├── terminal.lua              # Multiplexing, PTY execution, smart splits
│       ├── vcs.lua                   # Version control, gitsigns, diffview, worktrees
│       ├── data.lua                  # Databases, REPL, Molten Jupyter integration
│       ├── infrastructure.lua        # Cloud, Docker, Kubernetes, Terraform, Helm
│       ├── authoring.lua             # Scientific writing, Markdown, Quarto, LaTeX (vimtex)
│       ├── toolchain.lua             # External binary provisioning (mason.nvim registry)
│       ├── ai.lua                    # Autonomous AI pairing, MCP hub, CodeCompanion
│       │
│       ├── ui.lua                    # Shared UI primitives: statuscolumn, scroll, borders
│       ├── ui-dashboard.lua          # Zero-overhead entry dashboard & discrete dock
│       ├── ui-discovery.lua          # Keymap discovery (which-key)
│       ├── ui-notifications.lua      # macOS HIG notifications (snacks.notifier) + cmdline (noice)
│       ├── ui-status.lua             # Telemetry presentation statusline (lualine)
│       └── ui-theme.lua              # Aesthetic engine & highlight definitions
│
└── scripts/
    └── benchmark.py                  # Headless CI SLA validator (Hyperfine, AST, permissions)
```

---

## 4. Key Subsystem Architectures

### 4.1. Core Performance & Bootstrap Subsystem
- Located in [`x0r/lua/core/perf.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/perf.lua).
- Activates `vim.loader.enable()` bytecode cache before any modules are loaded.
- Disables all legacy remote host providers: `loaded_python3_provider = 0`, `loaded_ruby_provider = 0`, `loaded_node_provider = 0`, `loaded_perl_provider = 0`.
- Tunes LuaJIT garbage collector: `collectgarbage("setpause", 150)` and `collectgarbage("setstepmul", 300)` for smoother incremental collections without frame drops.

### 4.2. Large-File Runtime Governor
- Located in [`x0r/lua/core/guard.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/guard.lua).
- Connected directly to `BufReadPre` in [`x0r/lua/core/autocmds.lua`](file:///Users/x0r/.config/nvim/x0r/lua/core/autocmds.lua).
- Uses non-blocking `vim.uv.fs_stat` (never spawns `stat` or `ls`).
- **Tier 1 ($> 1\text{ MB}$):** Disables Treesitter, LSP attach, `vim.diagnostic`, mini.indentscope, and matchparen.
- **Tier 2 ($> 10\text{ MB}$):** Forces buffer into read-only binary-safe mode (`undolevels = -1`, `swapfile = false`, `buftype = "nowrite"`, syntax disabled).

### 4.3. UI Notifications & Message Architecture
- Located in [`x0r/lua/plugins/ui-notifications.lua`](file:///Users/x0r/.config/nvim/x0r/lua/plugins/ui-notifications.lua).
- **Single Responsibility Separation:**
  - **`folke/snacks.nvim` (Notifier Sink):** Sole owner of `vim.notify` rendering. Configured with macOS-native `style = "compact"` (title and icon embedded into rounded border), SF-style symbols, `level = vim.log.levels.INFO`, and auto-timeout of $2500\text{ms}$.
  - **In-Place Progress Pattern:** When notifications carry an `opts.id` (e.g. `id = "lsp_progress"`), Snacks mutates the single active toast on-the-fly rather than spawning dozens of stacked panels.
  - **`folke/noice.nvim` (Cmdline Only):** Explicitly restricted to `notify = { enabled = false }`, `messages = { enabled = false }`, and `lsp.progress = { enabled = false }` to prevent terminal command dumps or double spinners from breaking the workspace layout.

### 4.4. Terminal Hardening & PTY Discovery
- Set in fish / tmux environment: `set -gx SNACKS_KITTY 1`.
- Eliminates dynamic terminal escape queries (`\e[>q`) inside nested PTYs and tmux sessions, preventing `TermResponse` garbage leakage (e.g. `tty(0.49.1)`) from typing into active buffers.

---

## 5. Agent Rules of Engagement (Anti-Patterns to Reject)

When generating code or proposing changes in this workspace, you **MUST NEVER**:

| Forbidden Anti-Pattern | Why It Is Rejected | Required Solution |
| :--- | :--- | :--- |
| **Creating `lib/` or `utils/` directories** | Violates DDD and Single Responsibility. Leads to "junk drawer" code bloat. | Promote active governors to `core/`; isolate on-demand inspection tools to `core/audit/`. |
| **Calling `Snacks.notifier.notify(...)` directly in domain code** | Leaky Abstraction. Creates tight coupling to a third-party plugin and breaks headless tests. | Call only standard Neovim `vim.notify(...)`. UI routing belongs solely in `ui-notifications.lua`. |
| **Periodic polling timers (`vim.uv.new_timer()`)** | Violates the Zero-Overhead contract. Prevents event-loop idling and drains laptop battery. | Use native event autocommands (`LspProgress`, `BufWritePost`, etc.) or on-demand execution. |
| **Synchronous shell calls in Lua** | Blocks Neovim's single main thread, causing visible UI micro-stutters and frame drops. | Use `vim.system({ ... }, { text = true }, callback)` or `vim.uv`. |
| **Declaring `init` or `config` in satellite `snacks.nvim` specs** | Violates lazy.nvim spec merge semantics. `opts` and `keys` merge cleanly across files, but lifecycle hooks (`init`, `config`) silently overwrite each other. | Primary lifecycle belongs solely to `ui.lua` (`config`) and `ui-notifications.lua` (`init`). All other domains must provide only declarative `opts` and `keys`. |
| **Root `init.lua` trampolines** | Violates Neovim's native `$NVIM_APPNAME` multi-config architecture. Distorts `stdpath()` in C-runtime, mutates `package.path`, duplicates runtimepaths, and adds ~13ms of cold start latency. | Rely on native `NVIM_APPNAME=x0r nvim`. Keep root clean of synthetic dispatcher scripts. |
| **Full-screen opaque overlay hacks** | Degrades UX and blinds the user to real plugin installation errors and progress. | Rely on native `lazy.nvim` and `mason.nvim` UI modals with real progress indicators. |
| **Global `_G` symbol pollution** | Leaks variables across independent domains, causing subtle state corruption. | Keep all symbols strictly scoped inside local module tables (`local M = {}`). |

---

## 6. Verification & Quality Gates

Before concluding any refactoring or feature implementation, you **MUST** run and pass the following quality gates:

### Gate 1: Headless Core Invariant Audit (Must score 7/7 100.0%)
```bash
env XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless \
  -c "lua require('core.audit.doctor').run(); vim.wait(1000, function() return false end)" +qa
```

### Gate 2: Full Systems Benchmark Suite
```bash
python3 x0r/scripts/benchmark.py
```
*Structure, Plugins, Formatters, SLA, SecOps, and Latency domains must all score 100.0%.*

### Gate 3: Clean Headless Exit (0 stderr, returncode = 0)
```bash
env XDG_CONFIG_HOME=/Users/x0r/.config/nvim NVIM_APPNAME=x0r nvim --headless +qa
```

---

*Specification maintained by **zx0r**. Engineered for autonomous agents to execute with mathematical rigor.*
