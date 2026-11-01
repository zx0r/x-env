---
title: "Agent Client Protocol (ACP)"
module: acp/README.md
layer: Documentation
responsibility: "Architecture overview, system topology, operational guide, and CLI reference for the Neovim-Agent pairing suite"
dependencies: [functions/prj.fish, functions/acp.fish, ~/.config/nvim/zx0r/lua/core/acp.lua]
backlinks: [acp/architecture.md, acp/AGENTS.md, acp/ROADMAP.md, .meta/MAP_OF_CONTENT.md]
created_at: 2026-10-12
updated_at: 2026-10-12
tags: [acp, nvim, ipc, rpc, worktree, tmux]
---

# Agent Client Protocol (ACP)

A pair-programming workspace setup linking a developer in Neovim with an autonomous AI coding agent in an adjacent terminal pane, backed by a local Unix domain socket, MessagePack-RPC, and Git worktrees on macOS Darwin.

---

## 1. Problem & Design

When running autonomous CLI coding agents (`agy`, `claude`, `opencode`, `aider`), developers hit two core problems:

1. **Git Lock Contention:**  
   If the human and agent run concurrent git operations (`git status`, `git add`, `git commit`) in the same directory, execution fails with:  
   `fatal: Unable to create '.git/index.lock': File exists`.
2. **Context Blindness:**  
   If the agent is isolated in a standalone directory without editor telemetry, it has zero visibility into the developer's open file, cursor position, or active compiler diagnostics (`LSP`).

**ACP Solution:**  
A single Tmux window split into two dedicated panes:
* **Left Pane (Architect / Human):** Runs Neovim in the primary project workspace (`~/x/dev/own/<project>`) on branch `<project>`, listening on a dedicated local Unix socket (`--listen /tmp/nvim-<project>-<epoch>.sock`).
* **Right Pane (Agent / AI):** Runs the agent in an isolated Git worktree (`.worktrees/agent`) on branch `<project>-agent`. The pane inherits `NVIM_SOCKET` and interacts with Neovim via the `acp` CLI tool or direct MessagePack-RPC.

---

## 2. Spatial Topology

```text
┌───────────────────────────────────────────────┬───────────────────────────────────────────────┐
│ [project] ARCHITECT (Left Pane)               │ [project] AGENT (Right Pane)                  │
│                                               │                                               │
│  Editor: Neovim (Human)                       │  CLI Agent (agy / claude / opencode / aider)  │
│  Path: ~/x/dev/own/<project>                  │  Path: ~/x/dev/own/<project>/.worktrees/agent │
│  Git Branch: <project>                        │  Git Branch: <project>-agent                  │
│  Socket: /tmp/nvim-<project>-<epoch>.sock     │  Environment: NVIM_SOCKET=/tmp/nvim-...sock   │
│  Module: lua/core/acp.lua (_G.ACP)            │  CLI Suite: functions/acp.fish (command: acp) │
└───────────────────────────────────────┬───────┴───────────────────────▲───────────────────────┘
                                        │                               │
                                        └────────► [ AF_UNIX IPC ] ─────┘
                                                   • Sub-millisecond RPC (~34ms CLI e2e)
                                                   • Read active buffer directly from memory
                                                   • Query live compiler & LSP diagnostics
                                                   • Toast notifications via vim.notify
                                                   • Safe checktime buffer reloads
```

---

## 3. System Components

### 3.1. Workspace Orchestrator: `functions/prj.fish`
Command: `prj <project_name>`
* Creates the project root at `~/x/dev/own/<project_name>` if it does not exist.
* Configures Git branch lineage:
  - `main`: Clean baseline anchor commit.
  - `<project>`: Primary working branch for the human.
  - `<project>-agent`: Dedicated branch for autonomous agent execution.
* Provisions an isolated Git worktree at `.worktrees/agent`.
* Enables Git worktree isolation:
  - `git config extensions.worktreeConfig true`: per-worktree configuration support.
  - `git -C .worktrees/agent config --worktree gc.auto 0`: disables auto-gc in the agent worktree to eliminate global lock collisions.
* Sets up local exclusions:
  - Registers `.worktrees/` in `.git/info/exclude` (keeps public `.gitignore` clean).
  - Registers `.worktrees/` in `.ignore` (prevents Ripgrep, fd, and Telescope from scanning duplicate files).
  - Writes `*` to `.worktrees/.ignore`.
* Clones dependency directories via **APFS Copy-on-Write**:
  - Replicates `node_modules`, `.venv`, `target`, `vendor` using `cp -cR` (`clonefile(2)`).
  - Takes ~35ms and consumes **0 bytes** of extra disk space.
  - Guarded by `and not test -e` to prevent overwriting existing files.
* Splits the Tmux window:
  - Left pane launches `nvim --listen <socket_path>`.
  - Right pane navigates to `.worktrees/agent`, exports `NVIM_SOCKET`, and sets pane options.
  - Writes the active socket path to Tmux window option `@acp_socket`.

### 3.2. Neovim Server Module: `lua/core/acp.lua`
Loaded automatically in `init.lua`. Exposes the sandboxed `_G.ACP` namespace:
* `_G.ACP.ping()`: returns JSON with server status, PID, Neovim version, and uptime.
* `_G.ACP.get_context()`: returns active buffer info (filepath, bufnr, line count, cursor row/col, `changedtick`, modified flag, LSP error/warning counts).
* `_G.ACP.get_diagnostics(bufnr)`: returns active LSP diagnostics (line, col, severity, message, source).
* `_G.ACP.read_buffer(bufnr, start, end)`: reads buffer lines directly from Neovim's memory without hitting disk.
* `_G.ACP.apply_patch(params)`: applies atomic in-memory line replacements via `nvim_buf_set_lines`. Enforces optimistic locking (`expected_tick == vim.b[buf].changedtick`). If the human edited the buffer concurrently, the patch aborts with `CONCURRENCY_CONFLICT`. Preserves the editor undo-tree (`undotree`).
* `_G.ACP.reload_buffer(bufnr)`: triggers a non-destructive `:checktime` refresh.
* `_G.ACP.notify(message, level)`: renders a toast notification in Neovim (`vim.notify`).
* `BufWritePost` autocommand: asynchronously updates the Tmux window option `@acp_last_save` upon file saves.

### 3.3. Agent CLI Helper: `functions/acp.fish`
Command: `acp <subcommand>`
Automatically resolves the active Neovim socket from `$NVIM_SOCKET`, Tmux option `@acp_socket`, or scanning `/tmp/nvim-*.sock`.
Invokes remote expressions via `nvim --headless 2>&1` to prevent ANSI escape sequence pollution.

---

## 4. CLI Command Reference

All subcommands run directly from the agent's shell:

| Command | Purpose | Output Example |
| :--- | :--- | :--- |
| `acp ping` | Probe socket connectivity and measure RTT latency | `● ACP Pong: Connected to Neovim (RTT: 34ms)` |
| `acp context` | Human file context, cursor position, and LSP errors | `File: src/main.rs \| Line 42, Col 15 \| 1 errors` |
| `acp context --json` | Raw JSON context payload for agent scripts | `{"buffer": {...}, "cursor": {...}}` |
| `acp diags` | List all active compiler/LSP diagnostics | `[ERROR] Line 42:15 [rust-analyzer]: mismatched types` |
| `acp notify "<msg>"` | Display toast notification in human's Neovim pane | `✓ Notification dispatched to Architect pane` |
| `acp read` | Read active buffer lines directly from memory | Prints buffer lines to stdout |
| `acp reload` | Send checktime refresh signal to active buffer | `✓ Dispatched checktime to active buffer` |
| `acp status` | Print socket path, connection status, and worktree info | `Socket: ACTIVE (listening) \| Pane: rt:0.1` |

---

## 5. Safety Invariants

1. **Zero `rm` Policy:**  
   Scripts and functions contain zero `rm`, `rm -f`, or `rm -rf` commands. Socket paths incorporate epoch timestamps (`nvim-$project-$epoch.sock`), ensuring orphaned sockets from killed sessions never block new sessions and require no unlinking.
2. **Non-Destructive Worktree Cloning:**  
   Dependency replication uses APFS CoW (`cp -cR`) guarded by `and not test -e`, ensuring existing files are never overwritten.
3. **Optimistic Concurrency Guard:**  
   In-memory buffer patches check `b:changedtick`. If the human is actively typing, agent patches safely abort to prevent overwriting code.

---

## 6. Related Documentation

* [Architecture Specification](architecture.md)
* [Agent Rules of Engagement](AGENTS.md)
* [Implementation Roadmap & Task Tracker](ROADMAP.md)
