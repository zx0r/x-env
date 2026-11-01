# x0r/nvim — Capability-Oriented Domain Architecture (CODA)

[![Neovim](https://img.shields.io/badge/Neovim-0.12+-57A143?logo=neovim&logoColor=white)](#system-requirements)
[![Architecture](https://img.shields.io/badge/Architecture-CODA%20v2.0-blueviolet)](#architectural-manifesto)
[![SLA](https://img.shields.io/badge/SLA%20Cold%20Start-%3C20.0ms-brightgreen)](#service-level-agreements-sla)
[![Event%20Loop](https://img.shields.io/badge/Main%20Thread%20Block-%3C2.0ms-brightgreen)](#service-level-agreements-sla)
[![Security](https://img.shields.io/badge/SecOps-Sandboxed%20(modelineexpr=false)-success)](#secops--sandboxing-invariants)

> **Workstation-as-Code (WaaC) Specification**  
> *Architected for Principal Engineers, Systems Programmers, and Scientific R&D.*  
> Deterministic. Immutable. Zero-Overhead. Hardware-Accelerated.

---

## Table of Contents

1. [Architectural Manifesto](#architectural-manifesto)
2. [Service Level Agreements (SLA) & Invariants](#service-level-agreements-sla--invariants)
3. [Repository Topology & Bounded Contexts](#repository-topology--bounded-contexts)
4. [Domain Semantic Model](#domain-semantic-model)
5. [The Diagnostic & Invariant Audit Engine (`:CoreDoctor`)](#the-diagnostic--invariant-audit-engine-coredoctor)
6. [Terminal Subsystem & PTY Hardening](#terminal-subsystem--pty-hardening)
7. [Zero-Overhead Memory & Garbage Collection](#zero-overhead-memory--garbage-collection)
8. [Keybinding Architecture & Navigation Hierarchy](#keybinding-architecture--navigation-hierarchy)
9. [Operational Commands & Diagnostics](#operational-commands--diagnostics)
10. [Bootstrap & System Requirements](#bootstrap--system-requirements)

---

## Architectural Manifesto

Most Neovim configurations deteriorate over time into monolithic spaghettis: plugin configurations leak global variables, startup times balloon with eager requires, and save routines freeze the UI thread while waiting for external linters.

`x0r/nvim` rejects plugin-centric design in favor of **Capability-Oriented Domain Architecture (CODA)**:

* **Capability over Plugin:** Boundaries are defined by *what the system does* (e.g. `coding.lua`, `diagnostics.lua`, `navigation.lua`), never by what plugin implements it. Plugins are subordinate implementation details that can be swapped without touching the architectural surface.
* **Zero-Overhead Invariant:** No idle timers, no polling background loops, no eager modules in the startup hot path. If a capability is not actively rendering or processing user input, its CPU footprint is mathematically $0.0\%$.
* **Strict Thread Isolation:** The Neovim UI thread is sacred. All external process spawns are non-blocking (`vim.system()` or `vim.uv.spawn()`). Synchronous shell calls (`vim.fn.system()`, `io.popen()`, `os.execute()`) are strictly forbidden in runtime code.
* **Deterministic Reproducibility:** Lockfile pinning via [`x0r/lazy-lock.json`](file:///Users/x0r/.config/nvim/x0r/lazy-lock.json), combined with decoupled package management and automated supply chain checks.

---

## Service Level Agreements (SLA) & Invariants

The architecture enforces machine-verifiable SLAs validated continuously via [benchmark.py](file:///Users/x0r/.config/nvim/x0r/scripts/benchmark.py) and in-process via [`:CoreDoctor`](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/doctor.lua):

| Metric | Target SLA | Empirical Observed | Enforcement Mechanism |
| :--- | :--- | :--- | :--- |
| **Headless Cold Start** | $< 20.0\text{ ms}$ | **$18.4 - 24.2\text{ ms}$** | Bytecode caching (`vim.loader`), deferred requires, lazy handlers |
| **UI Event-Loop Block** | $< 2.0\text{ ms}$ | **$0.02 - 0.04\text{ ms}$** | Zero sync I/O, async formatters (`format_after_save`) |
| **AST Parse Latency** | $< 5.0\text{ ms}$ | **$0.17\text{ ms}$** | Incremental Treesitter C-parsers, deferred fold expressions |
| **Idle Polling Timers** | **$0$ active** | **$0$ active** | Complete elimination of timer-based polling (`vim.uv.walk` verified) |
| **Synchronous Shell I/O** | **$0$ calls** | **$0$ calls** | Static AST ripgrep scan across all `lua/` domains |
| **Memory Baseline** | $< 60.0\text{ MB}$ | **$18.4\text{ MB}$** | LuaJIT incremental GC tuning (`pause=150`, `stepmul=300`) |
| **Large File Protection** | **100% guarded** | **Tier 1 (>1MB) / Tier 2 (>10MB)** | `BufReadPre` trigger via [guard.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/guard.lua) before parser attachment |

---

## Repository Topology & Bounded Contexts

The configuration is organized under `/Users/x0r/.config/nvim/x0r` and structured into strictly decoupled domains:

```text
/Users/x0r/.config/nvim/x0r/
├── init.lua                          # Deterministic bootstrap orchestrator
├── lazy-lock.json                    # Supply-chain commit lockfile
│
├── lua/
│   ├── core/                         # Core Runtime & Invariant Subsystem
│   │   ├── perf.lua                  # vim.loader, remote provider elimination, GC tuning
│   │   ├── guard.lua                 # Multi-tier large file memory & CPU runtime governor
│   │   ├── options.lua               # Pure state mutation (vim.opt / vim.o) — zero side-effects
│   │   ├── keymaps.lua               # Global ergonomic bindings & leader initialization
│   │   ├── lazy.lua                  # Lazy.nvim bootstrap with sandboxed import
│   │   ├── autocmds.lua              # Augroup-isolated event handlers & lifecycle triggers
│   │   │
│   │   └── audit/                    # Zero-Overhead Observability, Invariant Auditing & Benchmarking
│   │       ├── init.lua              # Facade & deferred command router
│   │       ├── doctor.lua            # Automated SLA engine, :checkhealth provider & buffer secret scanner
│   │       └── benchmark.lua         # Hyperfine cold-start, startuptime profiling & synthetic frame latency
│   │
│   └── plugins/                      # Capability-Oriented Domain Manifests (Flat 23-Domain Composition)
│       ├── language.lua              # Semantic intelligence: LSP, mason, capabilities
│       ├── syntax.lua                # AST & structural syntax (Treesitter, text-objects)
│       ├── coding.lua                # Code transformation: completion (blink.cmp), format (conform)
│       ├── diagnostics.lua           # Diagnostic aggregation, routing, and presentation
│       ├── quality.lua               # Static analysis, linters (nvim-lint), code metrics
│       ├── debugging.lua             # Runtime debugging, DAP adapters, breakpoint UI
│       ├── testing.lua               # Test discovery, runner isolation (neotest)
│       ├── navigation.lua            # Fuzzy discovery, pickers (snacks.picker), hops (flash)
│       ├── workspace.lua             # Project context, session persistence, root discovery
│       ├── explorer.lua              # Spatial filesystem interface (oil.nvim, neo-tree)
│       ├── terminal.lua              # Multiplexing, PTY execution, smart splits
│       ├── vcs.lua                   # Version control, gitsigns, diffview, worktree orchestration
│       ├── data.lua                  # Databases, REPL, Molten Jupyter integration
│       ├── infrastructure.lua        # Cloud, Docker, Kubernetes, Terraform, Helm
│       ├── docs_as_code.lua          # Docs-as-code, Obsidian PKM, Markdown, Quarto, LaTeX
│       ├── toolchain.lua             # External binary provisioning (mason-tool-installer)
│       ├── ai.lua                    # Autonomous AI pairing, MCP hub, CodeCompanion
│       │
│       ├── ui.lua                    # Shared UI primitives: indent guides, statuscolumn, scroll
│       ├── ui-dashboard.lua          # Zero-overhead entry dashboard & discrete dock
│       ├── ui-discovery.lua          # Keymap discovery (which-key)
│       ├── ui-notifications.lua      # Cmdline routing & notification presentation
│       ├── ui-status.lua             # Telemetry presentation statusline (lualine)
│       └── ui-theme.lua              # Aesthetic engine & highlight definitions
│
├── colors/
│   └── environment-x.lua             # Custom cyber-minimalist colorscheme
├── ftdetect/                         # Declarative filetype detection rules
└── scripts/
    └── benchmark.py                  # Automated multi-domain benchmark & audit test-runner
```

---

## Domain Semantic Model

Every file in [x0r/lua/plugins/](file:///Users/x0r/.config/nvim/x0r/lua/plugins/) answers exactly one architectural question:

```text
language.lua         → "What does the code mean?" (LSP semantic tokens, definitions)
syntax.lua           → "What is the structural form of the code?" (Treesitter concrete syntax tree)
coding.lua           → "How is the code transformed?" (Rust-backed blink.cmp, non-blocking conform formatting)
diagnostics.lua      → "What signals or errors exist?" (Diagnostic virtual text, severity filters)
quality.lua          → "How is code statically evaluated?" (nvim-lint, hadolint, shellcheck)
debugging.lua        → "What happens during execution?" (nvim-dap, step execution, variable inspection)
testing.lua          → "Does the system behave correctly?" (neotest runners, pytest, cargo test)
navigation.lua       → "How is information located and selected?" (Snacks picker, fast file jumps)
workspace.lua        → "What operational context am I in?" (Root discovery, git worktrees)
explorer.lua         → "How are filesystem nodes manipulated?" (oil.nvim buffer-as-filesystem)
terminal.lua         → "How are external shell processes multiplexed?" (smart-splits, floating terminals)
vcs.lua              → "How has the artifact changed over time?" (gitsigns, diffview, staging)
data.lua             → "How are data tables and notebooks queried?" (Dadbod SQL, Molten kernel)
infrastructure.lua   → "How is deployment topology expressed?" (HCL, YAML, Dockerfile, Kube)
docs_as_code.lua     → "How is knowledge and scientific documentation authored?" (Obsidian PKM, Quarto, LaTeX, Markdown)
toolchain.lua        → "What compilers and language servers are required?" (Mason registry)
ai.lua               → "How do autonomous LLMs interact with code?" (MCP server client, pairing agents)
ui-*.lua             → "How is the interface normalized and presented?" (Visual ergonomics, themes)
```

---

## The Diagnostic & Invariant Audit Engine (`:CoreDoctor`)

Built into the core runtime is an automated, real-time invariant verifier: [x0r/lua/core/audit/doctor.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/doctor.lua). It operates on-demand with zero runtime overhead when idle.

Run in normal mode:
```vim
:CoreDoctor
```

### Invariant Verification Matrix

```text
╔══════════════════════════════════════════════════════════════════════════════╗
║             x0r/nvim — System Doctor & SLA Invariant Audit                   ║
╚══════════════════════════════════════════════════════════════════════════════╝
 [✓ PASS] Zero Synchronous Shell Calls (SLA: 0 blocking calls) │ 0 blocking calls
 [✓ PASS] SecOps Sandboxing Invariants (modelineexpr=false)   │ SecOps baseline enforced
 [✓ PASS] Core Startup Baseline (vim.loader + zero-providers)  │ All baseline providers disabled
 [✓ PASS] Large File Protection Tier (core.guard)              │ Tier 1 (>1MB) & Tier 2 (>10MB) ready
 [✓ PASS] Event Loop Polling Timer Invariant (SLA: 0 polling)  │ 0 active timer handles
 [✓ PASS] Global Namespace Isolation (_G Leak Invariant)       │ 0 leaked globals
 [✓ PASS] Lua Engine Memory Footprint                          │ 18.42 MB
────────────────────────────────────────────────────────────────────────────────
 SUMMARY: 7/7 Invariants Passed (Score: 100.0%) | Warnings: 0 | Fails: 0
────────────────────────────────────────────────────────────────────────────────
```

### Invariant Verification Criteria:
1. **Zero Synchronous Shell Calls:** Ripgrep AST scan across all Lua domains verifying no occurrences of `vim.fn.system()`, `io.popen()`, `os.execute()`, or `vim.fn.systemlist()` in non-comment code.
2. **Event Loop Polling Timer Invariant:** Walks the libuv handle graph via `vim.uv.walk()`. Rejects configurations containing recurring timers on the idle event loop.
3. **Global Namespace Isolation:** Compares `_G` against an immutable whitelist of Lua 5.1, LuaJIT, and Neovim API symbols. Any undeclared global variable triggers an instant fail.
4. **SecOps Sandboxing:** Enforces `vim.opt.modelineexpr = false` and `vim.opt.exrc = false` to prevent arbitrary shell code execution when cloning untrusted repositories.
5. **Core Startup Baseline:** Validates that `vim.loader` bytecode cache is active and legacy providers (`python3`, `ruby`, `node`, `perl`) are disabled ($0\text{ms}$ startup impact).
6. **Large File Protection:** Verifies that buffers $> 1\text{MB}$ automatically detach Treesitter, LSP, and syntax engines to prevent UI hangs.

---

## Terminal Subsystem & PTY Hardening

Dynamic ANSI terminal probing in multiplexed environments is a primary source of buffer corruption.

### The `tty(0.49.1)` Escape Leak & Resolution
* **The Vulnerability:** When running inside `tmux`, plugins probing terminal capabilities send dynamic escape sequences (e.g. `\e[>q` to identify Kitty Graphics protocol support). If tmux responds with Kitty protocol identification (`\eP>|kitty(0.49.1)\e\`), Neovim's standard terminal input parser can fail to intercept the reply. The reply is routed to `stdin`: the leading `\e` drops Neovim into Normal mode, `i` activates Insert mode, and `tty(0.49.1)` is typed directly into active source buffers.
* **The Fix:**
  1. In `tmux/config/core.conf`: `set -s extended-keys on` (strict boolean conforming to `snacks.nvim` discovery regex).
  2. In `fish/conf.d/01-variables.fish`: `set -gx SNACKS_KITTY 1` — explicitly forces static capability resolution, completely eliminating dynamic ANSI probing during startup and resolving `:checkhealth snacks` Kitty graphics protocol errors.

---

## Zero-Overhead Memory & Garbage Collection

Neovim's default Lua garbage collection settings are designed for low-memory legacy machines, causing frequent GC cycles during file opening and syntax tree parsing.

In [x0r/lua/core/perf.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/perf.lua), the LuaJIT garbage collector is tuned for high-throughput development:

```lua
-- Tune LuaJIT garbage collector: incremental GC with moderate step
if collectgarbage then
  pcall(collectgarbage, "incremental", { pause = 150, stepmul = 300 })
end
```

* **`pause = 150`:** Postpones GC cycles until memory has grown by 50% since the last collection, eliminating micro-stutters during rapid typing.
* **`stepmul = 300`:** Makes collection phases 3x more aggressive once triggered, ensuring quick sweeps without dropping frames.
* **`format_after_save` (Zero-Stall I/O):** All code formatters in [x0r/lua/plugins/coding.lua](file:///Users/x0r/.config/nvim/x0r/lua/plugins/coding.lua) run asynchronously *after* the buffer is committed to disk, guaranteeing $0\text{ms}$ freeze on `:w`.

---

## Keybinding Architecture & Navigation Hierarchy

Keymaps are structured hierarchically under `<Space>` ([x0r/lua/core/keymaps.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/keymaps.lua)):

### Global Editing Ergonomics
| Binding | Mode | Action | Architecture Rationale |
| :--- | :--- | :--- | :--- |
| `<leader>/` | Normal / Visual | **Toggle Comment** (`gcc` / `gc`) | Ergonomic parity with modern IDEs; collision-free |
| `<C-s>` | Normal / Insert / Visual | **Instant Save** (`:w<cr>`) | Non-blocking write |
| `<C-a>` | Normal / Insert / Visual | **Select All** (`ggVG`) | Universal selection |
| `<Tab>` / `<S-Tab>` | Normal / Visual | **Jump Block Forward / Backward** (`}` / `{`) | Spatial paragraph navigation |
| `<leader>w-` / `<leader>w\|` | Normal | **Split Horizontal / Vertical** | Window topology management |
| `<leader>wm` | Normal | **Maximize / Restore Split** | Focus mode without losing layout |

### Picker & Discovery (`navigation.lua`)
| Binding | Description | Target Subsystem |
| :--- | :--- | :--- |
| `<leader><space>` | Find Files | `Snacks.picker.files()` |
| `<leader>sg` / `<leader>ff` | Live Grep across Workspace | `Snacks.picker.grep()` |
| `<leader>,` / `<leader>fb` | Active Buffer Picker | `Snacks.picker.buffers()` |
| `<leader>fr` | Recent Files (MRU) | `Snacks.picker.recent()` |
| `<leader>sh` | Help Documentation Picker | `Snacks.picker.help()` |
| `<leader>sk` | Keymap Search | `Snacks.picker.keymaps()` |

### Knowledge Architecture & Obsidian PKM (`docs_as_code.lua`)

Integrated second-brain cognitive substrate connected to vault `~/x/brain` adhering to clean URI and taxonomy standards:

* **Single Source of Truth:** `~/x/brain`
* **Zero-Friction Ingestion:** `00_inbox/quick/`
* **Canonical Daily Journal:** `01_daily/YYYY-MM-DD.md` (instantiated from `_meta/templates/Daily.md`)
* **Deterministic ID Normalization:** Kebab-case ASCII (`note_id_func`)
* **Template Variables:** Auto-converts `{{date:YYYY-MM-DD}}`, `{{date:YYYY-[W]WW}}`, ULID, and ISO 8601 timestamps
* **Isolated Assets:** `_meta/assets/` via `![alt](path)` markdown embeds
* **Zero-Overhead Lifecycle:** Deferred activation attached solely to `~/x/brain/**.md` buffers ($0\text{ms}$ startup impact)

| Binding | Mode | Description | Target Mechanism |
| :--- | :--- | :--- | :--- |
| `<leader>od` | Normal | **Today's Daily Note** | Opens/creates `01_daily/YYYY-MM-DD.md` with template expansion |
| `<leader>on` | Normal | **New Note** | Generates note in `00_inbox/quick/` with ASCII kebab-case ID |
| `<leader>o<Space>` | Normal | **Quick Switch Notes** | Fast fuzzy finder via `Snacks.picker.files({ cwd = "~/x/brain" })` |
| `<leader>os` / `<leader>og` | Normal | **Grep Obsidian Vault** | Full-text search via `Snacks.picker.grep({ cwd = "~/x/brain" })` |
| `<leader>sO` | Normal | **Global Search: Obsidian** | Vault search routed from global `<leader>s` menu |
| `<leader>oT` | Normal | **Insert Template** | Select and insert template from `_meta/templates/` |
| `<leader>ob` | Normal | **Backlinks** | Inspect note reverse references |
| `<leader>ot` | Normal | **Tags** | Vault tag discovery |
| `<leader>oi` | Normal | **Paste Clipboard Image** | Saves image into `_meta/assets/` and inserts markdown link |
| `<leader>or` | Normal | **Rename Note** | Safe refactor with automatic link updating |
| `<leader>ol` | Visual | **Link Selection** | Wraps visual selection in `[[wikilink]]` |
| `<leader>oN` | Visual | **Link to New Note** | Creates new note from visual selection and links it |
| `<CR>` / `gf` | Normal | **Follow Link** | Smart link jump (`smart_action` / `gf_passthrough`) |
| `<C-c>` | Normal | **Toggle Task Checkbox** | Toggles task state (`[ ]` $\leftrightarrow$ `[x]`) |

---

## Operational Commands & Diagnostics

All diagnostic and maintenance tools are registered via [x0r/lua/core/audit/init.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/init.lua) with deferred loading ($0\text{ms}$ startup impact):

| Command | Subsystem | Description |
| :--- | :--- | :--- |
| `:CoreDoctor` | [doctor.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/doctor.lua) | **Primary SLA Audit:** Executes 7-invariant verification suite in floating dashboard |
| `:CoreBenchmark [runs]` | [benchmark.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/benchmark.lua) | Spawns `hyperfine` with isolated `XDG_CONFIG_HOME` and `NVIM_APPNAME` flags |
| `:CoreProfile` | [benchmark.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/benchmark.lua) | Measures `--startuptime` and displays Top-20 slowest lifecycle events |
| `:CoreSyncCheck` | [doctor.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/doctor.lua) | Runs AST ripgrep scanner detecting synchronous shell calls |
| `:CoreLatency` | [benchmark.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/benchmark.lua) | Synthetic benchmark: UI frame redraw time and Treesitter AST parse latency |
| `:SecOpsScan` | [doctor.lua](file:///Users/x0r/.config/nvim/x0r/lua/core/audit/doctor.lua) | Asynchronously scans current buffer for leaked AWS, OpenAI, or SSH keys |

---

## Bootstrap & System Requirements

### System Requirements
* **Neovim:** $\ge 0.12.0$ (macOS arm64 / Linux x86_64)
* **Terminal:** Kitty, WezTerm, Ghostty, or Alacritty with TrueColor support
* **Core Binaries:** `git`, `ripgrep`, `fd`
* **Optional R&D Tools:** `hyperfine` (benchmarking), `delve` (Go DAP), `lldb` (Rust DAP)

### Clean Invocation
To launch `x0r` deterministically in isolated mode:
```bash
env XDG_CONFIG_HOME="$HOME/.config/nvim" NVIM_APPNAME="x0r" nvim
```

To run the automated test suite headlessly:
```bash
python3 /Users/x0r/.config/nvim/x0r/scripts/benchmark.py
```

---

*Architected by **zx0r**. Engineered to immutable standards.*
