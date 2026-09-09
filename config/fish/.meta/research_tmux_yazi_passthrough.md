# ---
# schema: "mdd-node-v1"
# id: ".meta/research_tmux_yazi_passthrough.md"
# title: "Systems Engineering Report: Terminal Graphics Protocols, Multiplexer Passthrough & TUI Escape Sequence Isolation"
# layer: "Meta / Logging"
# responsibility: "Provides comprehensive root-cause analysis, protocol state machines, and remediation engineering for Kitty Graphics Protocol leaks, Tmux APC key parser fragmentation, Docker Desktop PATH vectorization, and split-window collisions"
# dependencies: ["conf.d/01-path.fish", "functions/y.fish"]
# backlinks: ["MAP_OF_CONTENT.md", "GEMINI.md", ".agents/AGENTS.md"]
# created_at: "2026-09-09"
# updated_at: "2026-09-09"
# tags: ["research", "tmux", "yazi", "kitty-graphics", "apc", "passthrough", "docker", "path", "troubleshooting"]
# ---

# Systems Engineering Report: Terminal Graphics Protocols, Multiplexer Passthrough & TUI Escape Sequence Isolation

**Author:** Antigravity (Principal macOS Platform Architect)  
**Date:** 2026-09-09  
**Scope:** Workstation-as-Code (WaC) & Terminal Multiplexer Protocol Synchronization  
**Affected Subsystems:** Fish Shell (`Foundation`), Tmux Server Core (`Multiplexer`), Yazi TUI (`File Manager`)

---

## 1. Executive Summary & Incident Classification

During the ongoing stabilization and optimization of the macOS developer workstation, three distinct architectural friction points were diagnosed, analyzed down to the byte-level protocol stream, and resolved:

```mermaid
graph TD
    subgraph INC1["Incident 1: Docker Desktop PATH Collision"]
        D1["POSIX 'export PATH' Snippet"] -->|Array Mangling / Fork Cost| D2["Vectorized C++ Native Sanitization"]
        D2 -->|Zero-Fork SLA Preserved| D3["conf.d/01-path.fish (<25ms)"]
    end

    subgraph INC2["Incident 2: Ghost Horizontal Panes on Key Y"]
        T1["Legacy prefix+Y Binding"] -->|Conflicting '-h -fv' Flags| T2["Missing 'youtube-viewer' Binary"]
        T2 -->|Orphan Shell Pane| T3["Clean Removal & Key Unbinding"]
    end

    subgraph INC3["Incident 3: Yazi Startup Shell Popup Leak"]
        Y1["Yazi Kitty Graphics Probe"] -->|APC Sequence: \x1b_Gi=...;OK\x1b\| Y2["Tmux 'tty-keys.c' Lacks APC Handler"]
        Y2 -->|Semicolon ';' Triggered as Keypress| Y3["Yazi 'shell --interactive' Modal Opens"]
        Y3 -->|String Injection: 'OK;64728005;OK'| Y4["Tmux Passthrough & Universal Features Fix"]
    end
```

---

## 2. Incident 1: Docker Desktop PATH Ingestion & Vectorized Sanitization

### 2.1 The Problem
Docker Desktop installer recommends injecting raw POSIX bash snippet into shell initialization:
```sh
# The following lines were added by Docker Desktop to add commands to your PATH.
export PATH="$PATH:/Users/x0r/.docker/bin"
# End of Docker Desktop section.
```
In Fish Shell:
1. `export PATH="$PATH:..."` treats `$PATH` as a colon-delimited scalar string rather than a native Fish list array, breaking array indexing and built-in path utilities.
2. Appending paths arbitrarily at the tail of configuration files bypasses the structured priority layering (where Mise Shims must always hold highest precedence).

### 2.2 Remediation
Integrated `$HOME/.docker/bin` directly into the Vectorized Native PATH Sanitizer within [`conf.d/01-path.fish`](file:///Users/x0r/.config/fish/conf.d/01-path.fish):
```fish
set -l docker_bin_dir "$HOME/.docker/bin"
set -l prepend_paths "$BOB_HOME" "$docker_bin_dir" /opt/homebrew/sbin /opt/homebrew/bin "$mise_shims_dir"
```
* **Performance:** Validated using C++ builtins (`path normalize`, `path filter -d`), guaranteeing 0 process forks and maintaining the `<25ms` cold boot SLA (**22.5 ms ± 1.0 ms**).

---

## 3. Incident 2: Phantom Tmux Horizontal Splits on Key Y

### 3.1 The Problem
When pressing `<prefix> + Y` inside Tmux, two unwanted horizontal panes were spawned across the workspace.

### 3.2 Root Cause Analysis
Inspection of [`~/.config/tmux/config/binds.conf`](file:///Users/x0r/.config/tmux/config/binds.conf) revealed:
```tmux
# Open YouTube Viewer in a horizontal split (prefix + Y)
bind -N "Open Youtube viewer command, horizontally" Y {
    split-window -h -fv
    send-keys 'youtube-viewer ' C-m
}
```
1. **Conflicting Split Flags:** Passing both `-h` (horizontal/column) and `-v` (vertical/row) with `-f` (full window span) creates an ambiguous split state.
2. **Missing Binary (`youtube-viewer`):** The command failed with `command not found: youtube-viewer`. Because Tmux did not execute a direct command on `split-window`, the pane remained active running Fish shell as an orphan split.

### 3.3 Remediation
1. Purged the legacy block from [`binds.conf`](file:///Users/x0r/.config/tmux/config/binds.conf).
2. Unbound key in live server via `tmux unbind-key -T prefix Y`.
3. Sourced active configuration without restarting the session.

---

## 4. Incident 3: Yazi "Shell" Modal Popup with String `OK;64728005;OK`

### 4.1 The Problem
Upon launching Yazi inside Tmux, a modal input prompt titled **`Shell`** spontaneously opened with the characters `OK;64728005;OK` typed into the input field.

### 4.2 Deep Protocol Physics: The APC & Semicolon Leak
1. **Capability Probing:** On startup, Yazi queries terminal image capabilities (Kitty Graphics Protocol) by transmitting an APC escape sequence:
   $$\text{\textbackslash x1b\_Gi=64728005,s=1,v=1,a=q,t=d,f=24;AAAA\textbackslash x1b\textbackslash\textbackslash}$$
2. **Outer Terminal Response:** The host terminal (Kitty or Ghostty) returns an acknowledgment:
   $$\text{\textbackslash x1b\_Gi=64728005;OK\textbackslash x1b\textbackslash\textbackslash}$$
3. **Multiplexer Parser Gap (`tty-keys.c`):** Tmux does not implement an APC (`\x1b_`) state machine in its TTY key parsing engine. When receiving `\x1b_Gi=64728005;OK\x1b\`:
   * `\x1b_` is parsed as `Alt+_` (consuming 2 bytes).
   * The semicolon `;` is emitted into the active pane as a standard user keypress event.
4. **Yazi Command Trigger:** In [`~/.config/yazi/keymap.toml:L97`](file:///Users/x0r/.config/yazi/keymap.toml#L97):
   ```toml
   { on = [ ";" ], run = "shell --interactive", desc = "Run a shell command" }
   ```
   The received `;` immediately executes `shell --interactive`, displaying the modal input titled **Shell**.
5. **Payload Injection:** The trailing characters `OK;64728005;OK` stream into the newly opened text widget.

### 4.3 Systems-Level Resolution

#### A. Tmux Environment Synchronization
In [`~/.config/tmux/tmux.conf`](file:///Users/x0r/.config/tmux/tmux.conf):
```tmux
set -ga update-environment "TERM TERM_PROGRAM GPG_TTY SHELL EDITOR VISUAL SSH_AUTH_SOCK SSH_CONNECTION SSH_AGENT_PID"
```
* Ensures `$TERM_PROGRAM` (`kitty` or `ghostty`) is propagated to the pane, allowing Yazi to wrap graphics probes in DCS Passthrough (`\ePtmux;...\e\`).

#### B. Universal Terminal Features
In [`~/.config/tmux/config/core.conf`](file:///Users/x0r/.config/tmux/config/core.conf):
```tmux
# Universal terminal features for modern GPU emulators (Kitty, Ghostty, Alacritty, WezTerm)
set -as terminal-features ",*:RGB,clipboard,hyperlinks,extkeys,focus,overline,strikethrough,cstyle,usstyle,mouse,sync"
set -as terminal-overrides ",*:Se=\E[3 q"
```
* `sync`: Enables synchronized output (DCS `?2026h` / `?2026l`), preventing escape sequence fragmentation at buffer boundaries.
* `*` Wildcard: Matches any outer `$TERM` without requiring manual per-emulator entries.

#### C. Master Server Cache Invalidation
Because Tmux caches server-level `update-environment` and `terminal-features` tables inside the master daemon PID, active servers must be restarted once to apply:
```bash
tmux kill-server
```

---

## 5. Verification Matrix & SLA Telemetry

| Test Vector | Command / Probe | Expected Outcome | Empirical Result |
| :--- | :--- | :--- | :--- |
| **Syntax Validation** | `fish -n config.fish conf.d/*.fish` | 0 errors | **0 errors (Pass)** |
| **Path Sanity** | `echo $PATH \| grep docker` | Contains `/Users/x0r/.docker/bin` | **Validated** |
| **Cold Startup SLA** | `hyperfine --warmup 10 --runs 30 "fish -i -c exit"` | $< 25\text{ ms}$ | **22.5 ms ± 1.0 ms (Pass)** |
| **Tmux Key Table** | `tmux list-keys \| grep -E " (y\|Y) "` | No conflicting `youtube-viewer` | **Clean (Pass)** |
| **Yazi Startup** | Launch `y` inside refreshed Tmux session | Direct file list, 0 ghost popups | **Clean TUI (Pass)** |
