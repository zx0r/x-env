# The Environment of X

[![Taxonomy](https://img.shields.io/badge/Taxonomy-Meta--Workspace_v1.0-blue.svg)](#meta-workspace-taxonomy)
[![Compliance](https://img.shields.io/badge/Compliance-XDG_Base_Directory-green.svg)](#xdg-specification)
[![Architecture](https://img.shields.io/badge/Architecture-4--Zone_Model-orange.svg)](#4-zone-architecture)

> **Paradigm:** Workstation as Code (WaC)  
> **Author:** [zx0r](https://github.com/zx0r)  
> **License:** MIT  
> **Platform:** macOS · Apple Silicon (arm64)  
> **Shell SLA:** < 25 ms cold startup · **Achieved:** 9.5 ms base / 21.0 ms full interactive

---

## Abstract

**`x-env`** is a system substrate (Environment Substrate) and a foundational layer for declarative workspace management (**Workspace as Code / WaC**) within the **Meta-Workspace (`~/x (X-MADE) Meta-Workspace`)** ecosystem.

The module is responsible for the idempotent initialization of the system environment, deterministic configuration of the CLI stack, strict isolation of XDG paths, and the provision of a base platform for interaction between humans and AI agents.

Targeting macOS on Apple Silicon hardware, the repository structures user configurations
under a centralized namespace (`config/`), designed for symlink projection into the host
system in strict adherence to the **XDG Base Directory Specification** (`~/.config/`).

The core of the environment is a layered, decade-spaced modular architecture (`00–59`)
within the Fish interactive shell. All shell initialisation routines are governed by a
**Zero-Fork SLA (< 25 ms)**, achieved through static cache pre-compilation, vectorized C++
in-memory PATH sanitisation, In-Memory Sentinel Guards, and lazy cryptographic TTY bindings.
The configuration suite encompasses terminal emulation (Kitty, Alacritty, iTerm2), session
multiplexing (Tmux), shell history (Atuin), syntax-highlighted tooling (Bat, Ripgrep), and
Git workflows (Lazygit).

---

## Table of Contents

1. [Design Principles](#1-design-principles)
2. [Repository Structure](#2-repository-structure)
3. [System Architecture](#3-system-architecture)
   - [3.1 Shell Initialisation Topology](#31-shell-initialisation-topology)
   - [3.2 Zero-Fork Performance Model](#32-zero-fork-performance-model)
   - [3.3 Metadata Schema mdd-node-v1](#33-metadata-schema-mdd-node-v1)
4. [Toolchain Inventory](#4-toolchain-inventory)
   - [4.1 Terminal Emulators](#41-terminal-emulators)
   - [4.2 Shell and Prompt](#42-shell-and-prompt)
   - [4.3 Session Multiplexer](#43-session-multiplexer)
   - [4.4 Developer Utilities](#44-developer-utilities)
   - [4.5 Security and Privacy Infrastructure](#45-security-and-privacy-infrastructure)
5. [Key Engineering Implementations](#5-key-engineering-implementations)
6. [Performance Benchmarks](#6-performance-benchmarks)
7. [Diagnostics and Auditing](#7-diagnostics-and-auditing)
8. [Bootstrap and Reproduction](#8-bootstrap-and-reproduction)
9. [Project Conventions](#9-project-conventions)

---

## 1. Design Principles

The architecture of this workstation configuration is governed by the following invariants:

| Principle | Implementation Constraint |
|:---|:---|
| **Declarative State** | All configuration is expressed as text files committed to version control. No runtime state exists that cannot be reconstructed from the repository. |
| **Zero-Fork SLA** | Shell initialisation must not spawn blocking subshells. Dynamic evaluations (`fork-exec` cycles) on the critical boot path are prohibited. |
| **Idempotency** | Every bootstrap routine is safe to execute multiple times with no side-effects beyond the first application. |
| **Layered Separation of Concerns** | Configuration is partitioned into decade-spaced layers with strict dependency ordering, enforcing a clear bounded-context model. |
| **Self-Healing Caches** | Static pre-compiled caches are invalidated automatically via `test -nt` binary-sensitive comparisons, requiring no manual intervention after tool upgrades. |
| **Lazy Evaluation** | Resources not consumed on every shell spawn (GPG TTY, tab completions, micromamba hooks) are deferred to first-use autoload wrappers. |
| **Programmatic Auditability** | All `.fish` modules carry a structured YAML header conforming to the `mdd-node-v1` schema, enabling dependency graph resolution by agentic tooling. |
| **Cryptographic Integrity** | All commits are signed with an Ed25519 GPG key (`86D3 756D 93BD A9FE`), providing a tamper-evident provenance chain for every configuration change. |

---

## 2. Repository Structure

```
zx0r-workstation/
└── config/                          # Root configuration namespace
    ├── alacritty/                   # Alacritty terminal emulator
    │   ├── alacritty.toml           #   Primary configuration
    │   ├── fonts/                   #   Font declarations
    │   ├── scripts/                 #   Helper scripts
    │   └── themes/                  #   Color scheme profiles
    ├── atuin/                       # Atuin fuzzy shell history engine
    │   └── config.toml              #   Sync, search, and daemon config
    ├── bat/                         # Bat syntax-highlighted pager
    │   ├── bat.conf                 #   Global options
    │   ├── syntaxes/                #   Custom syntax definitions
    │   └── themes/                  #   Custom color themes
    ├── ccstatusline/                # Custom status line component
    ├── curl/                        # cURL network client
    ├── dnscrypt-proxy/              # DNSCrypt privacy proxy
    │   └── dnscrypt-proxy.toml      #   Resolver, DoH, and audit config
    ├── fish/                        # Fish interactive shell (primary)
    │   ├── config.fish              #   Main entrypoint & orchestrator
    │   ├── conf.d/                  #   Decade-spaced modular layers
    │   │   ├── 00-xdg.fish          #     Foundation: XDG directory layout
    │   │   ├── 01-path.fish         #     Foundation: Vectorized PATH sanitisation
    │   │   ├── 01-variables.fish    #     Foundation: Core environment variables
    │   │   ├── 02-brew.fish         #     Foundation: Static Homebrew mapping
    │   │   ├── 10-runtimes.fish     #     Infrastructure: Self-healing cache engine
    │   │   ├── 11-ssh-gpg.fish      #     Infrastructure: SSH/GPG daemon routing
    │   │   ├── 20-abbr.fish         #     Commands: Abbreviations registry
    │   │   ├── 30-ux.fish           #     UX: Prompt & presentation
    │   │   ├── 40-keymaps.fish      #     Input: Vi-mode bindings
    │   │   ├── 50-fzf.fish          #     Tooling: FZF integration
    │   │   ├── 50-utils.fish        #     Tooling: Developer utilities
    │   │   └── 99-local.fish        #     Extension: Machine-local overrides (git-ignored)
    │   ├── functions/               #   Lazy-autoloaded command wrappers
    │   ├── completions/             #   Deferred tab-completion registries
    │   ├── themes/                  #   Interactive color scheme switcher
    │   ├── fish_plugins             #   Fisher plugin manifest
    │   └── README.md                #   Sub-system architecture reference
    ├── iterm2/                      # iTerm2 terminal emulator
    │   ├── com.googlecode.iterm2.plist
    │   └── iterm2-sync/             #   JSON-serialised settings & import tooling
    ├── kitty/                       # Kitty GPU-accelerated terminal emulator
    │   ├── kitty.conf               #   Primary configuration (3 197 lines)
    │   ├── themes/                  #   14 color themes (Cyberdream, Dracula, etc.)
    │   ├── scripts/                 #   Tab-bar, split-window, dark-mode automation
    │   └── session                  #   Default session layout
    ├── lazygit/                     # Lazygit TUI git client
    │   └── config.yml               #   CyberPunk Edition — Delta, Neovim, Yazi
    ├── ripgrep/                     # Ripgrep search engine
    │   ├── ripgreprc                #   Global search options
    │   └── ripgrep_ignore           #   Global ignore patterns
    ├── starship/                    # Starship cross-shell prompt engine
    │   └── starship.toml            #   CyberPunk Neon / Carbonfox palettes
    ├── tmux/                        # Tmux terminal multiplexer
    │   ├── tmux.conf                #   Primary configuration
    │   ├── config/                  #   Modular sub-configurations
    │   │   ├── core.conf            #     Session & window defaults
    │   │   ├── binds.conf           #     Key bindings
    │   │   ├── plugins.conf         #     Plugin declarations
    │   │   ├── hooks.conf           #     Lifecycle hooks
    │   │   └── theme.conf           #     Theme routing
    │   ├── scripts/                 #   Status-bar data providers
    │   │   ├── cpu.sh / mem.sh / ssd.sh / network.sh / uptime.sh
    │   │   ├── git.sh               #     Git branch & status widget
    │   │   ├── fzf-panes.sh         #     FZF-driven pane navigator
    │   │   └── ai/                  #     AI-assisted shell workflow scripts
    │   ├── theme/                   #   Dual-mode themes (dark.tmux / light.tmux)
    │   └── README.md
    ├── wget/                        # wget network client (wgetrc)
    ├── colorsdb                     # Named color reference database
    ├── eza_colors                   # Eza directory lister color overrides
    ├── fish_variables               # Fish universal variable store
    ├── iconsdb                      # Nerd Font icon reference database
    └── ls_colors                    # GNU LS_COLORS compiled from trapd00r/LS_COLORS
```

---

## 3. System Architecture

### 3.1 Shell Initialisation Topology

Fish shell configuration files located in `conf.d/` are evaluated in lexicographic (ASCII) order prior to `config.fish`. A **decade-spaced decimal topology** is imposed to guarantee deterministic dependency resolution:

```
config.fish  (Orchestrator)
└── conf.d/
    ├── 00–09  Foundation Layer    · XDG dirs · PATH · Homebrew · Variables
    ├── 10–19  Infrastructure Layer · Self-Healing Cache Engine · SSH/GPG Routing
    ├── 20–29  Commands Layer       · Abbreviations · Filesystem Utilities
    ├── 30–39  UX / Styling Layer   · Prompt · Cursor · Color Themes
    ├── 40–49  Input Layer          · Vi-Mode Keybindings · Widget Triggers
    ├── 50–59  Tooling Layer        · FZF · Bat · Zoxide · Neovim
    └── 90–99  Extension Layer      · Machine-Local Overrides (git-ignored)
```

#### Layer Classification Matrix

| Range | Bounded Context | Core Responsibility |
|:---|:---|:---|
| **00–09** | Foundation | XDG directory bootstrapping, in-memory PATH sanitisation, static Homebrew mapping, locale & telemetry opt-outs |
| **10–19** | Infrastructure | Parallel static cache compilation for Starship / Zoxide / Atuin / FZF; SSH socket forwarding; async GPG agent refresh |
| **20–29** | Commands | Abbreviation registry; macOS subsystem maintenance commands; filesystem utility functions |
| **30–39** | UX / Styling | Asynchronous prompt rendering, Vi-cursor state transitions, interactive color scheme loading |
| **40–49** | Input | Vi-mode bindings, FZF widget key assignments, clipboard integration |
| **50–59** | Tooling | FZF environment options, Bat pager theme, Zoxide configuration, Neovim launcher |
| **90–99** | Extension | Machine-local credentials and private overrides; git-ignored, not committed to repository |

---

### 3.2 Zero-Fork Performance Model

Traditional shell initialisation sequences accumulate 80–150 ms of latency through repeated `fork-exec` cycles. This architecture systematically eliminates each category of blocking subprocess:

| Eliminated Fork | Conventional Approach | Zero-Fork Replacement |
|:---|:---|:---|
| `starship init fish \| source` | Spawns external process on every boot | Pre-compiled to `$XDG_CACHE_HOME/fish/static_init/starship.fish`; sourced directly |
| `zoxide init fish \| source` | Spawns external process on every boot | Same static cache strategy |
| `atuin init fish \| source` | Spawns external process + UUID fork | Cached + patched: `atuin uuid` replaced with native Fish `random` arithmetic |
| `eval (brew shellenv)` | Executes Ruby interpreter (~40 ms) | Replaced by static variable declarations in `02-brew.fish` |
| `set -gx GPG_TTY (tty)` | Synchronous `/usr/bin/tty` subprocess | Deferred to lazy autoload wrappers: `git.fish`, `gpg.fish`, `pass.fish` |
| Micromamba shell hook | Reads massive completion sets (~5.9 ms) | Isolated to `functions/micromamba.fish`; completions deferred to `Tab` trigger |
| `fish_add_path` | Blocking sync write to universal variables | Replaced by in-memory C++ builtins `path normalize` + `path filter -d` |

Cache invalidation is performed via native `test -nt` (newer-than) comparisons against the tool binary and configuration files. If either changes, the cache is regenerated asynchronously (backgrounded with `&`) and PIDs are collected for a single synchronous `wait` before source.

---

### 3.3 Metadata Schema mdd-node-v1

All `.fish` modules carry a structured YAML front-matter header enabling programmatic dependency graph resolution and agentic tooling ingestion:

```fish
# ---
# schema: "mdd-node-v1"
# id: "conf.d/10-runtimes.fish"
# title: "Self-Healing Runtime Cache Engine"
# layer: "Infrastructure (10-19)"
# responsibility: "Manages compiled static initializers for Mise, Starship, Zoxide, Atuin, and FZF"
# dependencies: ["conf.d/01-variables.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-07-12"
# tags: ["cache", "runtimes", "performance", "mise"]
# ---
```

This schema enables tools and AI agents to resolve load-order topologies, detect circular dependencies, and generate audit reports without executing the shell.

---

## 4. Toolchain Inventory

### 4.1 Terminal Emulators

| Tool | Role | Notable Configuration |
|:---|:---|:---|
| **Kitty** | Primary GPU-accelerated terminal | 3 197-line config; 14 color themes; tab-bar Python plugin; dark-mode automation; split-window kitten |
| **iTerm2** | macOS-native fallback | JSON-serialised settings with Python import/split tooling for diffable version control |
| **Alacritty** | Minimal GPU terminal | TOML-based; Nerd Font declarations; themed variants |

### 4.2 Shell and Prompt

| Tool | Role | Notable Configuration |
|:---|:---|:---|
| **Fish** | Primary interactive shell | Decade-spaced modular topology; zero-fork SLA; 70+ autoloaded functions |
| **Starship** | Cross-shell prompt engine | CyberPunk Neon & Carbonfox palettes; Nerd Font icons; Neovim version via `bob` |
| **Atuin** | Fuzzy shell history with sync | SQLite-backed; UUID fork eliminated via native Fish arithmetic |
| **Zoxide** | Frecency-based directory navigation | Static cached; aliases: `z`, `zi` |
| **FZF** | General-purpose fuzzy finder | Key bindings; preview widgets; git integration; process management |

### 4.3 Session Multiplexer

| Tool | Role | Notable Configuration |
|:---|:---|:---|
| **Tmux** | Terminal multiplexer | Modular 5-file config split; dual light/dark themes; AI workflow scripts; FZF pane navigator; real-time status bar (CPU, RAM, SSD, network, git, uptime) |

### 4.4 Developer Utilities

| Tool | Role | Notable Configuration |
|:---|:---|:---|
| **Lazygit** | TUI git client | CyberPunk Edition; Delta diff renderer; Neovim editor integration; Yazi file manager; custom author colors & branch patterns |
| **Ripgrep** | High-performance text search | Global ignore patterns; custom search options |
| **Bat** | Syntax-highlighted pager | Custom syntaxes and themes; used as `man` pager |
| **Eza** | Modern `ls` replacement | Custom EZA_COLORS; Nerd Font icons; git integration |
| **Mise** | Polyglot runtime version manager | Zero-fork: `mise activate` bypassed; shims directory as single PATH source of truth |
| **Yazi** | Terminal file manager | Integrated with Lazygit and shell via `y` function |
| **Neovim** | Primary editor | Launched via lazy wrapper; version tracked in Starship via `bob` |

### 4.5 Security and Privacy Infrastructure

| Tool | Role | Notable Configuration |
|:---|:---|:---|
| **DNSCrypt-Proxy** | Privacy-preserving DNS resolver | DoH/DNSCrypt; custom resolver list; DNS leak test scripts |
| **GPG** | Cryptographic identity | Ed25519 key; all commits signed; lazy TTY binding via function wrappers |
| **SSH Agent** | Key authentication | Symlink-stable socket (`~/.ssh/ssh_auth_sock`) for Tmux pane compatibility; optional GPG agent delegation |
| **Pass** | Unix password manager | GPG-integrated; lazy TTY wrapper |

---

## 5. Key Engineering Implementations

### 5.1 Self-Healing Static Cache Compiler

The `10-runtimes.fish` layer implements a parallel cache regeneration engine. For each tool (Starship, Zoxide, Atuin, FZF), the logic follows:

1. **Check** — Does the cache file exist? Is the tool binary newer than the cache?
2. **Regenerate** — If invalidated, spawn the `init` command as a background process (`&`), collect PID.
3. **Wait** — After all background processes are started, issue a single `wait $cache_pids`.
4. **Patch** — Post-process `atuin.fish` to replace the `atuin uuid` subprocess call with native Fish `random` arithmetic.
5. **Source** — Load all cached files directly from disk (< 0.5 ms per file).

### 5.2 XDG-Compliant Directory Taxonomy

The `00-xdg.fish` layer establishes a strict XDG Base Directory specification alongside a workstation-specific directory taxonomy:

```fish
# Meta-Workspace Taxonomy (~/x Human-Agent Ecosystem)
$X_ROOT → "$HOME/x"      # Meta-Workspace    
$X_MIND → "$X_ROOT/mind" # Knowledge Base / Cognitive Graph / Obsidian
$X_AGY  → "$X_ROOT/agy"  # AI Agent Hub (Skills, Rules, MCP)
$X_DEV  → "$X_ROOT/dev"  # Engineering & Development Space
$X_ENV  → "$X_ROOT/env"  # WaC / Dotfiles / Environment Substrate
├── config/              # (cfg) Utility configurations: kitty, tmux, fish, starship, nvim
├── scripts/             # Idempotent bootstrap, symlinkers, validators
├── vendor/              # Git submodules, external dependencies, mSCP
└── build/               # Generated artifacts, temporary builds, state

# Standard XDG directories
XDG_CONFIG_HOME   → "~/.config"
XDG_CACHE_HOME    → "~/.cache"
XDG_DATA_HOME     → "~/.local/share"
XDG_STATE_HOME    → "~/.local/state"
XDG_BIN_HOME      → "~/.local/bin"
XDG_RUNTIME_DIR   → "$TMPDIR"
```

All workstation directories are bootstrapped with `mkdir -p -m 700` on first launch, ensuring secure permissions with no manual intervention required.

### 5.3 SSH Socket Stability in Multiplexed Environments

Tmux panes inherit `SSH_AUTH_SOCK` from the session at creation time. When macOS rotates the socket (e.g., after sleep/wake), nested panes reference stale paths. The `11-ssh-gpg.fish` implementation creates a stable symlink at `~/.ssh/ssh_auth_sock` pointing to the current socket, then sets `SSH_AUTH_SOCK` to the symlink path. All panes reference the symlink; only the symlink target needs updating on reconnect.

### 5.4 Mise Zero-Fork Integration

The `MISE_FISH_AUTO_ACTIVATE=0` flag is set in `00-xdg.fish` *before* Homebrew's vendor `conf.d` directory is evaluated. This suppresses the Homebrew-installed `mise-activate.fish` vendor hook (which would otherwise execute `mise activate fish | source`, costing ~40 ms). Runtime version resolution is delegated entirely to Mise shims injected into `$PATH` via `01-path.fish`.

### 5.5 Vectorized PATH Sanitisation

Rather than iterating over path components with shell loops or writing to Fish universal variables (which incur blocking disk I/O), `01-path.fish` uses Fish's native C++ builtins:

```fish
path normalize $raw_paths | path filter -d | ...
```

This sanitises, normalises, and deduplicates the `$PATH` array in a single in-process C++ execution pass with no external subshell spawns.

---

## 6. Performance Benchmarks

| Metric | Target | Achieved |
|:---|:---|:---|
| Base shell cold startup | < 25 ms | **9.5 ms** |
| Full interactive profile | < 50 ms | **21.0 ms** |
| Static cache source per tool | — | **< 0.5 ms** |
| Homebrew env fork elimination | ~40 ms saved | ✓ |
| Micromamba hook deferral | ~5.9 ms saved | ✓ |
| GPG TTY fork elimination | ~2–5 ms saved | ✓ |

Benchmarks produced with:

```bash
hyperfine --warmup 10 'fish -i -c exit'
fish --profile-startup /tmp/fish.prof -ic exit && sort -nrk2 /tmp/fish.prof | head -20
```

---

## 7. Diagnostics and Auditing

### 7.1 Startup Hotspot Analyzer

```bash
profile_startup
```

Executes a full diagnostic trace: lists the top-10 slowest startup commands (inclusive vs. exclusive execution time), reports active static cache sizes, and runs a formal `hyperfine` benchmark.

### 7.2 Cache Eviction and Reload

```bash
refresh_shell_cache
```

Forces eviction of all pre-compiled static caches and reboots the active shell session, triggering a clean regeneration cycle on next launch.

### 7.3 DNS Integrity Audit

```bash
dns-audit
dnsleaktest
```

Fish functions that invoke DNSCrypt-Proxy diagnostic queries, verify resolver identity, and test for DNS leak exposure.

### 7.4 Commit Signature Verification

```bash
git log --show-signature --oneline
```

All commits carry a verifiable Ed25519 GPG signature. Unsigned or invalidly-signed commits indicate repository tampering.

---

## 8. Bootstrap and Reproduction

> **Note:** This section describes the conceptual reproduction pathway. A dedicated bootstrap script is planned for a future release.

To reproduce this workstation configuration on a fresh macOS Apple Silicon installation:

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Clone the repository
git clone https://github.com/zx0r/zx0r-workstation.git ~/x/dev/zx0r-workstation

# 3. Symlink configuration namespace
ln -sfh ~/x/dev/zx0r-workstation/config ~/.config

# 4. Install Fish shell
brew install fish
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

# 5. Install toolchain via Homebrew and Mise
# (refer to config/fish/conf.d/02-brew.fish for complete package list)

# 6. Launch Fish — self-healing cache engine bootstraps automatically on first run
fish
```

All caches, directory layouts, and environment variables are bootstrapped automatically by the modular initialisation layers. No interactive prompts or manual post-configuration steps are required.

---

## 9. Project Conventions

### Commit Message Format

This project follows the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

Types: feat · fix · perf · refactor · chore · docs · style · test
Scope: fish · tmux · kitty · config · starship · ...
```

All commits are GPG-signed. Unsigned commits are not accepted.

### Configuration File Authorship Header

All primary configuration files include a standardised authorship block:

```
Author       : zx0r
License      : MIT License
Contact Info : https://github.com/zx0r
```

### Branch Convention

| Branch | Purpose |
|:---|:---|
| `main` | Stable, deployed configuration |
| `feat/*` | Experimental feature integration |
| `perf/*` | Performance optimisation branches |

---

## References

- Fish Shell Documentation: <https://fishshell.com/docs/current/>
- XDG Base Directory Specification: <https://specifications.freedesktop.org/basedir-spec/latest/>
- Starship Prompt: <https://starship.rs>
- Mise Runtime Manager: <https://mise.jdx.dev>
- DNSCrypt-Proxy: <https://dnscrypt.info>
- Atuin Shell History: <https://atuin.sh>
- Zoxide: <https://github.com/ajeetdsouza/zoxide>
- Lazygit: <https://github.com/jesseduffield/lazygit>
- trapd00r/LS_COLORS: <https://github.com/trapd00r/LS_COLORS>

---

<div align="center">

*Stay hungry. Stay foolish.*

</div>
