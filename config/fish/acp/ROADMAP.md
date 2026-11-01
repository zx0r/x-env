---
title: "Agent Client Protocol (ACP) Roadmap"
module: acp/ROADMAP.md
layer: Planning & Architecture
responsibility: "Implementation milestones, architectural enhancements, and task tracker for ACP multi-agent orchestration"
dependencies: [functions/prj.fish, functions/acp.fish, ~/.config/nvim/zx0r/lua/core/acp.lua]
backlinks: [acp/README.md, acp/AGENTS.md, acp/architecture.md, .meta/MAP_OF_CONTENT.md]
created_at: 2026-10-13
updated_at: 2026-10-13
tags: [acp, roadmap, tasks, multi-agent, tmux, worktree]
---

# Agent Client Protocol (ACP) Roadmap

Implementation milestones and technical enhancements for the human-agent pair programming workstation and multi-worker orchestration suite.

---

## 1. Multi-Agent Worker Orchestration

- [ ] **Multi-Worktree Worker Provisioning (`prj worker add <name> [task]`)**
  - [ ] Add CLI support for provisioning named workers beyond the default lead agent (`.worktrees/<name>` on branch `<project>-<name>`).
  - [ ] Automate APFS Copy-on-Write cloning (`cp -cR`) for build/dependency folders (`node_modules`, `.venv`, `target`, `vendor`).
  - [ ] Configure worktree-level Git isolation (`extensions.worktreeConfig true`, `gc.auto 0`).
  - [ ] Enforce container boundary marker (`*` in `.worktrees/.ignore`).

- [ ] **Headless Worker Session Isolation**
  - [ ] Isolate background workers into a dedicated headless Tmux session: `<project>-workers`.
  - [ ] Prevent window tab pollution in the main human editor session.
  - [ ] Assign one window per worker (`tests`, `api`, `docs`, `refactor`).
  - [ ] Inject environment variables per worker window: `NVIM_SOCKET`, `PROJECT_NAME`, `WORKTREE_ROOT`, `WORKER_NAME`, `CARGO_TARGET_DIR`.

- [ ] **Worker Metadata & Telemetry Storage**
  - [ ] Store status in Tmux window options: `@worker_status` (`running`, `idle`, `done`, `failed`).
  - [ ] Store task context in Tmux window options: `@worker_task` (e.g. `Running pytest suite`).
  - [ ] Link active Neovim socket via `@acp_socket` in the worker session.

- [ ] **Safe Worker Lifecycle Control**
  - [ ] Implement `prj worker kill <name>` to stop worker processes (`SIGINT` / `C-c`) and close the window.
  - [ ] Maintain zero-destruction invariant: strictly ban `rm`, `rm -rf`, and `rm -f`; preserve worktree directory and branch history.

---

## 2. Agent Navigator (`agx` / Tmux Popup)

- [ ] **Single Popup Interface (`agx` / `tmux display-popup`)**
  - [ ] Create dedicated `functions/agx.fish` tool with interactive popup runner (`agx`).
  - [ ] Display dynamic worker count in modal title: `Agents (N)`.
  - [ ] High-density list format: `STATUS_ICON  NAME  BRANCH  TASK_CONTEXT`.
  - [ ] Filter / discover workers across `<project>-workers` and lead agent pane.

- [ ] **Live Terminal Preview**
  - [ ] Implement `agx preview <target>` for `fzf --preview`.
  - [ ] Display metadata header: project, branch status, worktree path, socket connectivity, process uptime.
  - [ ] Stream real-time ANSI-colored terminal output from target worker pane via `tmux capture-pane -ep -t <target> -S -40`.

- [ ] **Interactive Actions & Keybindings**
  - [ ] `<Enter>`: Switch client to selected worker window (`tmux switch-client -t <target>`).
  - [ ] `<Ctrl-n>`: Interactively prompt for name/task and spawn new worker.
  - [ ] `<Ctrl-k>`: Send graceful interrupt and close worker window without file deletion.
  - [ ] Quick return to editor using standard Tmux last-session toggle (`Prefix + Tab` / `switch-client -l`).

- [ ] **Tmux Configuration Wiring**
  - [ ] Add `agx` to Tmux Command Palette in `~/.config/tmux/config/binds.conf`.
  - [ ] Bind shortcut (e.g. `Prefix + a` or `Prefix + w` / `M-a`) to open Agent Navigator popup.

---

## 3. IPC Protocol & Telemetry Enhancements

- [ ] **Worker Status Reporting CLI**
  - [ ] Add `acp worker status <state>` to allow agents to report status (`running`, `done`, `idle`, `failed`).
  - [ ] Add `acp worker task <description>` to update live task context.
  - [ ] Add `acp worker done [summary]` to mark completion and dispatch toast notification to Architect pane.

- [ ] **Atomic Buffer Patching CLI (`acp patch`)**
  - [ ] Expose `_G.ACP.apply_patch` through `acp patch <file> <diff_or_lines>` CLI.
  - [ ] Enforce optimistic locking: verify `expected_tick == changedtick` before in-memory write.
  - [ ] Fail gracefully with `CONCURRENCY_CONFLICT` if human edited buffer concurrently.

- [ ] **Event-Driven Dispatch (Neovim -> Workers)**
  - [ ] Add optional Unix FIFO or socket subscription for editor events (`BufWritePost`, `DiagnosticChanged`).
  - [ ] Allow waiting agents to wake up on save without polling loops.

- [ ] **Neovim Status Telemetry**
  - [ ] Optional statusline / winbar component displaying active worker count (e.g. `󰚩 Workers: 3`).

---

## 4. Git Integration & Merge Workflows

- [ ] **Worker Merge Helper (`acp merge <worker>`)**
  - [ ] Provide command to inspect and merge worker branch (`<project>-<worker>`) into `<project>`.
  - [ ] Pre-merge safety checks: detect uncommitted changes and merge conflicts before modifying working tree.
  - [ ] Generate structured merge summary showing diff stat and commit messages.

- [ ] **Worktree Garbage Collection & Stale Session Audit**
  - [ ] Detect inactive worker worktrees where process has exited.
  - [ ] Provide safe archival / pruning without deleting uncommitted code.

---

## 5. Documentation & Alignment

- [ ] **Update `acp/README.md`**
  - [ ] Document multi-worker topology and `<project>-workers` session model.
  - [ ] Document `agx` popup navigator usage and shortcuts.

- [ ] **Update `acp/AGENTS.md`**
  - [ ] Add instructions for worker lifecycle reporting (`acp worker status`, `acp worker done`).
  - [ ] Define branch handoff rules for worker completion.

- [ ] **Register in System Index (`.meta/MAP_OF_CONTENT.md`)**
  - [ ] Add `acp/ROADMAP.md` to documentation and architecture index.
