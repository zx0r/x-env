<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS_Apple_Silicon-007AFF?style=flat-square&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/Shell-Fish_4.x-00CED1?style=flat-square" alt="Fish" />
  <img src="https://img.shields.io/badge/Terminal-Ghostty-FF6B35?style=flat-square&logo=ghostery&logoColor=white" alt="Ghostty" />
  <img src="https://img.shields.io/badge/Editor-Neovim-57A143?style=flat-square&logo=neovim&logoColor=white" alt="Neovim" />
  <img src="https://img.shields.io/badge/Multiplexer-Tmux-1BB91F?style=flat-square&logo=tmux&logoColor=white" alt="Tmux" />
  <img src="https://img.shields.io/badge/Security-Apple_Secure_Enclave-grey?style=flat-square&logo=apple&logoColor=white" alt="SEP" />
  <img src="https://img.shields.io/badge/KEX-ML--KEM--768-orange?style=flat-square" alt="PQC" />
</p>

<p align="center">
  <img src="assets/images/saas.webp" alt="Workstation Control Plane Banner" style="border-radius: 8px; max-width: 100%;" />
</p>

---

# x-config

### The System as Interface: A Zero-Latency Workstation Control Plane for macOS Apple Silicon

> **Coordinate:** `[c] config` $\in \mathcal{X} = \{\text{[a] agents}, \text{[b] brain}, \text{[c] config}, \text{[d] dev}\}$  
> **Compliance:** Strict XDG Base Directory Standard v0.8+ · POSIX IEEE Std 1003.1-2024  
> **Platform:** macOS Darwin (Apple Silicon arm64) · Cold Boot SLA: < 10.0 ms (3.82 ms non-interactive / 7.4 ms interactive)  
> **Security:** Zero-Disk-Leak Credential Model · Hardware-Anchored Identity (Apple Secure Enclave Processor)

---

## 1. Ontological Coordinate & Scope

`x-config` is the **deterministic Control Plane** of the personal computational environment. Within the four-domain model of **X Meta Workspace**, it governs how execution occurs across all actors and subsystems:

```text
[x] META-WORKSPACE ($HOME/x)
├── [a] agents    → Agency     (Who acts?)
├── [b] brain     → Knowledge  (What is known?)
├── [c] config    → Control    (How is execution governed?)  <-- [x-config]
└── [d] dev       → Production (What is constructed?)
```

`x-config` is **not a legacy dotfile repository**. It is a version-controlled, declarative single source of truth (SSOT) that governs system policies, toolchain declarations, and application runtimes while strictly isolating persistent configuration from volatile runtime state.

Targeting macOS on Apple Silicon hardware, the repository structures configurations under a centralized configuration namespace (`config/`), projected idempotently into the host system in strict adherence to the **XDG Base Directory Specification** (`~/.config/`). It establishes the deterministic execution baseline for both interactive human workflows and automated AI agents.

---

## 2. Invariants & Design Principles

| Principle | Implementation Invariant |
| :--- | :--- |
| **Declarative State** | All system and tool configurations are expressed as plain text committed to version control. No runtime state exists that cannot be reconstructed from this repository. |
| **Zero-Fork SLA** | Shell initialization eliminates blocking subshells. Dynamic evaluations (`fork-exec` cycles) on the critical boot path are strictly eliminated. |
| **Idempotency** | Every configuration deployment and bootstrap routine is safe to execute repeatedly with zero side-effects beyond the initial application. |
| **Layered Separation of Concerns** | Shell configuration is partitioned into decade-spaced layers (`00` to `50` and `90`) with strict dependency ordering, enforcing a clean bounded-context model. |
| **Self-Healing Caches (SWR)** | Static pre-compiled caches are invalidated via `test -nt` timestamp comparisons using Stale-While-Revalidate: the active session loads existing cache ($O(1)$, < 0.5 ms), while background workers rebuild asynchronously. |
| **Lazy Evaluation** | Heavy resources not required on shell spawn (deep tab completions, environment flags, abbreviations) are deferred to first-use autoload wrappers or prompt hooks. |
| **Hardware-Anchored Cryptography** | Commits are cryptographically signed via hardware Secure Enclave (`PROTOCOL.sshsig` / Secretive Touch ID). Private keys never touch NVMe storage or general RAM. |

---

## 3. Repository Architecture

The root repository layout strictly isolates user-space configurations and package manifests into two core operational trees:

```text
x-config/ ($HOME/x/config)
├── config/                       # Single Source of Truth for $XDG_CONFIG_HOME (~/.config)
│   ├── fish/                     # Shell: decade-spaced conf.d/ topology & SWR cache engine
│   ├── ghostty/                  # Primary GPU terminal: native macOS Zig renderer
│   ├── kitty/                    # Terminal: tab-bar automation, custom themes
│   ├── alacritty/                # Minimal GPU terminal
│   ├── tmux/                     # Terminal multiplexer: 3-window model & stage routing
│   ├── nvim/                     # Primary editor: Capability-Oriented Domain Architecture
│   ├── starship/                 # Cross-shell prompt (pre-compiled into AOT cache)
│   ├── git/                      # Git: Secure Enclave commit signing & APFS normalization
│   ├── jj/                       # Jujutsu VCS: conflict-first workflow
│   ├── ssh/                      # OpenSSH: post-quantum KEX & deterministic socket hashing
│   ├── bat/                      # Syntax-highlighted pager (17+ custom syntaxes)
│   ├── yazi/                     # Modern async terminal file manager
│   ├── ripgrep/                  # High-performance search & ignore rules
│   ├── dnscrypt-proxy/           # DoH/DNSCrypt encrypted DNS
│   ├── pf/                       # macOS Packet Filter firewall rules
│   ├── macos-security/           # NIST / CIS / DISA STIG compliance baselines
│   ├── obsidian/                 # Knowledge management vault configuration
│   ├── karabiner/                # Keyboard remapping rules
│   ├── btop/                     # System & hardware resource monitor
│   ├── curl/ & wget/             # Hardened network clients (TLS 1.3, ML-KEM-768)
│   ├── colorsdb & iconsdb        # Canonical named color & Nerd Font icon reference
│   └── ls_colors & eza_colors    # Terminal directory colorization specifications
│
├── pkg/                          # Declarative System & Toolchain Manifests
│   ├── Brewfile                  # Homebrew bundle (CLI utilities, GUI casks, fonts, AI agents)
│   ├── mise.toml                 # Environment substrate, XDG vars, toolchain versions
│   └── rustup.toml               # Rust toolchain components and targets
│
└── README.md                     # Systems architecture specification & benchmarks
```

---

## 4. Visual Showcase

<p align="center">
  <img src="assets/images/nvim.webp" alt="Neovim — Systems Engineering & Zero-Cost Architecture" style="border-radius: 8px; max-width: 100%;" />
</p>

<p align="center">
  <img src="assets/images/terminal.webp" alt="Ghostty Terminal — Display P3 Gamut & Typography Matrix" style="border-radius: 8px; max-width: 100%;" />
</p>

<p align="center">
  <img src="assets/images/tmux.webp" alt="Tmux Workspace & Subsystem Navigation" style="border-radius: 8px; max-width: 100%;" />
</p>

---

## 5. Performance Benchmarks

### Measurement Methodology

- **Hardware:** Apple Silicon (`arm64`, unified memory architecture).
- **Operating System:** macOS Darwin (XNU microkernel).
- **Measurement Tool:** `hyperfine` with 10 warmup runs across 150 benchmark iterations.
- **Scope:** End-to-end process creation, configuration evaluation, and shell exit.

```fish
hyperfine --warmup 10 -r 150 'fish -i -c exit'
```  

| Metric | mean | σ | min | max |
| :--- | :---: | :---: | :---: | :---: |
| **Wall Time [ms]** | **7.4** | 0.5 | 6.6 | 8.5 |
| **Memory [MiB]** | **6.6** | 0.0 | 6.5 | 6.7 |

```fish
fish --profile-startup /tmp/fish.prof -ic exit && sort -nrk2 /tmp/fish.prof | head -20
```

| Time (µs) | Sum (µs) | Command / Trace |
| :---: | :---: | :--- |
| 92 | 466 | `> for file in $__fish_config_dir/conf.d/*.fish $__fish_sysconf_dir/conf.d/*.fish...` |
| 116 | 270 | `-> source $file` |
| 19 | 202 | `> __fish_reconstruct_path` |
| 4 | 131 | `> if test -n "$XDG_DATA_DIRS"...` |
| 101 | 123 | `> status get-file __fish_build_paths.fish \| source` |
| 58 | 112 | `-> set xdg_data_dirs (string replace -r '([^/])/$' '$1' -- $xdg_data_dirs)/fish` |
| 4 | 110 | `-> if test (count $new_user_path) -lt (count $fish_user_paths)...` |
| 44 | 106 | `--> test (count $new_user_path) -lt (count $fish_user_paths)` |
| 1 | 104 | `> if status is-interactive...` |
| 16 | 99 | `-> __fish_theme_migrate` |
| 81 | 83 | `--> source /Users/x0r/.config/fish/functions/__fish_theme_migrate.fish` |
| 4 | 75 | `> if not set -q FISH_UNIT_TESTS_RUNNING...` |
| 5 | 62 | `--> if not set -q SSH_CLIENT...` |
| 59 | 59 | `---> count $new_user_path` |
| 54 | 54 | `--> string replace -r '([^/])/$' '$1' -- $xdg_data_dirs` |
| 39 | 51 | `-> set -l basename (string replace -r '^.*/' '' -- $file)` |
| 1 | 48 | `> if status is-interactive...` |
| 10 | 45 | `-> fish_config theme choose default --no-override` |
| 34 | 35 | `--> source /Users/x0r/.config/fish/functions/fish_config.fish` |
| 29 | 33 | `> builtin source /Users/x0r/.config/fish/config.fish` |

---

## 6. Zero-Fork Performance Model

Traditional shell initialization sequences accumulate 80–150 ms of latency through repeated `fork-exec` cycles. This control plane systematically eliminates each blocking subprocess:

| Eliminated Subprocess | Conventional Approach | Zero-Fork Replacement |
| :--- | :--- | :--- |
| `starship init fish \| source` | Spawns external process on every boot | Pre-compiled to `$XDG_CACHE_HOME/fish/static_init/starship.fish`; sourced directly |
| `zoxide init fish \| source` | Spawns external process on every boot | Pre-compiled to static cache file |
| `atuin init fish \| source` | Spawns external process + UUID fork | Cached + patched: `atuin uuid` replaced with native Fish `random` arithmetic |
| `eval (brew shellenv)` | Spawns Ruby interpreter (~40 ms) | Replaced by static variable declarations in `02_toolchain.fish` |
| `set -gx GPG_TTY (tty)` | Synchronous `/usr/bin/tty` subprocess | Bypassed via Secretive SSH signing; legacy fallback deferred to autoload wrapper |
| Micromamba shell hook | Reads massive completion sets (~5.9 ms) | Isolated to `functions/micromamba.fish`; completions deferred to `Tab` trigger |
| `fish_add_path` | Blocking universal variable write | Replaced by in-memory C++ builtins `path normalize` + `path filter -d` in `02_toolchain.fish` |

---

## 7. Subsystem Architecture

### 7.1 Interactive Shell Subsystem (Fish)

Fish shell configuration files located in [`config/fish/conf.d/`](config/fish/conf.d/) are evaluated in lexicographic (ASCII) order prior to `config.fish`. A **decade-spaced decimal topology** guarantees deterministic dependency resolution:

```text
config/fish/config.fish  (Orchestrator)
└── conf.d/
    ├── 00-09  Foundation Layer     · 00_bootstrap · 01_env · 02_toolchain (AOT PATH & mise)
    ├── 10-19  Infrastructure Layer · 10_hooks (SWR Cache) · 11_ipc (Secretive SSH Socket)
    ├── 20-29  Commands Layer       · 20_abbrs (Lazy JIT Abbreviations)
    ├── 30-39  UX / Styling Layer   · 30_ui (Prompt, Vi Cursor & Color Themes)
    ├── 40-49  Input Layer          · 40_bindings (Vi-Mode Keymaps & Widgets)
    ├── 50-59  Tooling Layer        · 50_search (FZF & Ripgrep Integrations)
    └── 90-99  Extension Layer      · 99_local (Machine-Local Overrides, git-ignored)
```

| Layer Range | Bounded Context | Canonical Modules | Core Responsibility |
| :--- | :--- | :--- | :--- |
| **00–09** | Foundation | `00_bootstrap.fish`<br/>`01_env.fish`<br/>`02_toolchain.fish` | XDG directory bootstrapping, static Homebrew mapping, unified AOT PATH static cache, mise shims compatibility, and telemetry opt-outs |
| **10–19** | Infrastructure | `10_hooks.fish`<br/>`11_ipc.fish` | SWR AOT cache engine (`frontend.fish`) and hardware Secure Enclave socket propagation (Secretive) |
| **20–29** | Commands | `20_abbrs.fish` | Abbreviation registry (JIT deferred); macOS subsystem maintenance commands; filesystem shortcuts |
| **30–39** | UX / Styling | `30_ui.fish` | Asynchronous prompt rendering, Vi-cursor state transitions, interactive color scheme loading |
| **40–49** | Input | `40_bindings.fish` | Vi-mode bindings, FZF widget key assignments, clipboard integration |
| **50–59** | Tooling | `50_search.fish` | FZF environment options, Ripgrep preview integrations, Bat pager theme, Zoxide configuration |
| **90–99** | Extension | `99_local.fish` | Machine-local credentials and private overrides; git-ignored, not committed to repository |

### 7.2 Terminal Multiplexer Subsystem (Tmux)

The Tmux configuration in [`config/tmux/`](config/tmux/) enforces cognitive load minimization through role-based window partitioning:
- **Three-Window Operational Model:** Sessions partition strictly into Window 1 (Dev — primary editor), Window 2 (Ops — Git, system maintenance, ad-hoc commands), and Window 3 (Run — active services, servers, databases).
- **Contextual Stage Routing (`stages/`):** Environment injection (`X_STAGE`) dynamically sources `stages/dev.tmux` or `stages/prod.tmux`, applying distinct border palettes and safety invariants.
- **Mode Schemas (`modes/`):** Toggles between `modes/human.tmux` for interactive keybindings and `modes/agent.tmux` for automated AI agent manipulation.
- **Persistent SSH Socket Symlink:** macOS rotates agent socket paths across sleep/wake events. Layer `11_ipc.fish` maintains an atomic symlink at `~/.ssh/ssh_auth_sock` pointing to the live socket, ensuring multiplexer panes never lose authentication state.

### 7.3 Primary Editor Subsystem (Neovim)

The editor configuration in [`config/nvim/`](config/nvim/) implements a Capability-Oriented Domain Architecture (CODA):
- **Domain Decoupling:** Flat domain manifests (`lua/plugins/*.lua`) define system capabilities (coding, navigation, diagnostics, LSP) rather than tying configuration to specific plugin implementations.
- **Three-Ring Execution Lifecycle:**
  - *Ring 0 (Instant Baseline, < 1.0 ms):* Bytecode loader (`vim.loader.enable()`), core performance overrides (`core.perf`), and direct theme rendering (`colorscheme("x")`).
  - *Ring 1 (Lazy Bootstrap, 5–15 ms):* Sandboxed plugin specification compilation via `lazy.nvim`.
  - *Ring 2 (Deferred Ergonomics):* Autocommands, `:CoreDoctor` invariant auditing, and keybindings deferred to `VeryLazy` event execution after the UI is interactive.
- **Zero-Overhead Invariants:** Zero active background polling timers (`vim.uv.walk` verified) and zero synchronous process executions (`vim.system` async execution only).

### 7.4 Hardware Cryptography & Secret Management

Security and authentication operate under a strict zero-ambient-leakage model:
- **Hardware-Anchored Identity (Apple Secure Enclave):** Master SSH keys reside exclusively in the Apple Secure Enclave Processor (SEP) managed via Secretive. Private keys never touch persistent SSD storage or general RAM. Git commits are cryptographically signed via `PROTOCOL.sshsig` bound to Touch ID authentication.
- **Deterministic Socket Hashing:** OpenSSH connection multiplexing utilizes deterministic SHA-1 connection parameter hashing (`ControlPath ~/.ssh/cm-%C`), capping Darwin Unix domain socket paths at ~59 bytes (well below the XNU 104-byte limit).
- **Post-Quantum Cryptographic Agility:** OpenSSH transport enforces ML-KEM-768 hybrid key exchange (FIPS 203) alongside Terrapin-immune AEAD ciphers (`aes256-gcm@openssh.com`).
- **Encrypted Master Store:** Declarative secrets are encrypted at rest using Mozilla SOPS with `age` keys (`~/.config/secrets.enc.yaml`).
- **Volatile RAM Cache & Scope-Isolated Execution:** Secrets resolve at runtime into a volatile RAM cache in `$TMPDIR/secrets.env` (< 1 ms latency). Functions `get-secret` and `with-secret` inject credentials strictly into child process memory scopes (`set -lx`), preventing ambient environment leakage.

---

## 8. Subsystem Registry

### Shell & Prompt

| Subsystem | Source Path | Role & Architecture |
| :--- | :--- | :--- |
| **Fish** | [`config/fish/`](config/fish/) | Primary interactive shell; decade-spaced `conf.d/` topology; SWR AOT cache; 7.4 ms cold boot |
| **Starship** | [`config/starship/`](config/starship/) | Cross-shell prompt; pre-compiled into static cache |
| **xstory** | [`config/fish/conf.d/`](config/fish/conf.d/) | Zero-copy mmap TSV shell history engine with tree-sitter highlighting |
| **FZF** | [`config/fish/functions/__x_init_fzf.fish`](config/fish/functions/__x_init_fzf.fish) | Fuzzy finder; Ripgrep preview pipelines; Git integration; process management |

### GPU Terminals

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Ghostty** | [`config/ghostty/`](config/ghostty/) | Primary GPU terminal; native macOS; Zig renderer; Display P3 color gamut |
| **Kitty** | [`config/kitty/`](config/kitty/) | Tab-bar plugin; dark-mode automation; split kitten; custom themes |
| **Alacritty** | [`config/alacritty/`](config/alacritty/) | Minimal GPU terminal; Catppuccin & Gruvbox themes |

### Terminal Multiplexer

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Tmux** | [`config/tmux/`](config/tmux/) | Modular config; dual themes; FZF pane nav; status bar (CPU, RAM, SSD, net, git, uptime) |

### Version Control & Attestation

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Git** | [`config/git/`](config/git/) | Touch ID commit signing (SSH `sshsig`); APFS normalization; FSEvents integration |
| **Jujutsu** | [`config/jj/`](config/jj/) | Git-compatible VCS; operation log; conflict-first workflow |
| **Lazygit** | [`config/lazygit/`](config/lazygit/) | Fast terminal UI for Git; Delta pager renderer; Neovim integration |
| **GitUI** | [`config/gitui/`](config/gitui/) | Rust-based high-throughput Git TUI |
| **GitHub CLI** | [`config/gh/`](config/gh/) | GitHub REST/GraphQL API workflows; PR/issue management |
| **Gitleaks** | [`config/gitleaks/`](config/gitleaks/) | Pre-commit secret scanning engine |
| **Cocogitto** | [`config/cocogitto/`](config/cocogitto/) | Conventional commits verification; automated changelog generation |
| **Commitlint** | [`config/commitlint/`](config/commitlint/) | Commit message standard format enforcement |
| **Lefthook** | [`config/lefthook/`](config/lefthook/) | High-performance polyglot Git hook orchestration |

### Search, Navigation & Pagers

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Ripgrep** | [`config/ripgrep/`](config/ripgrep/) | Global ignore patterns; binary skipping; custom search flags |
| **Bat** | [`config/bat/`](config/bat/) | 17+ custom syntaxes; 300+ themes; man pager integration |
| **Yazi** | [`config/yazi/`](config/yazi/) | Async terminal file manager; Starship integration; custom previewers |

### Network & Infrastructure Security

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **SSH** | [`config/ssh/`](config/ssh/) | Post-quantum KEX (ML-KEM-768); deterministic socket hashing (`cm-%C`); Secretive SEP |
| **pf** | [`config/pf/`](config/pf/) | macOS Packet Filter kernel firewall rules |
| **macOS Security** | [`config/macos-security/`](config/macos-security/) | NIST 800-53 / CIS Level 2 / DISA STIG baselines via mSCP |
| **cURL** | [`config/curl/`](config/curl/) | HTTP/3; ML-KEM-768 TLS 1.3; AppleSecTrust; XDG-isolated caches |
| **wget** | [`config/wget/`](config/wget/) | TLS 1.3 enforced; absolute path HSTS; APFS xattr preservation |
| **DNSCrypt-Proxy** | [`config/dnscrypt-proxy/`](config/dnscrypt-proxy/) | Encrypted DNS client supporting DoH and DNSCrypt protocols |

### Editors & Authoring

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Neovim** | [`config/nvim/`](config/nvim/) | Capability-Oriented Domain Architecture; 3-ring execution lifecycle; Bob version managed |
| **Obsidian** | [`config/obsidian/`](config/obsidian/) | Knowledge management vault configuration and styling |
| **Pandoc** | [`config/pandoc/`](config/pandoc/) | Universal document converter template library |
| **Glow** | [`config/glow/`](config/glow/) | Terminal markdown renderer |

### System & Input Configuration

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Karabiner-Elements** | [`config/karabiner/`](config/karabiner/) | Low-level kernel keyboard remapping and hyper-key rules |
| **Btop** | [`config/btop/`](config/btop/) | Terminal resource monitor (CPU, GPU, RAM, Disks, Networks) |

### Themes & Palette Databases

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **colorsdb** | [`config/colorsdb`](config/colorsdb) | Canonical 16/256-color palette dictionary |
| **iconsdb** | [`config/iconsdb`](config/iconsdb) | Nerd Font icon and glyph symbol reference |
| **ls_colors** | [`config/ls_colors`](config/ls_colors) | Comprehensive GNU LS_COLORS configuration |
| **eza_colors** | [`config/eza_colors`](config/eza_colors) | Eza directory color overrides |

### Declarative Package & Toolchain Manifests

| Subsystem | Source Path | Technical Specifications |
| :--- | :--- | :--- |
| **Brewfile** | [`pkg/Brewfile`](pkg/Brewfile) | Declarative Homebrew manifest (CLI tools, GUI casks, fonts, AI agent runtimes) |
| **Mise Substrate** | [`pkg/mise.toml`](pkg/mise.toml) | Environment substrate, XDG base directory enforcement, runtime tool versions |
| **Rustup Toolchain** | [`pkg/rustup.toml`](pkg/rustup.toml) | Rust toolchain components, compiler channels, and cross-compilation targets |

---

## 9. XDG Base Directory Mapping

All runtime state is isolated strictly under [XDG Base Directory Specification v0.8+](https://specifications.freedesktop.org/basedir-spec/latest/):

| Variable | Path | Core Responsibility |
| :--- | :--- | :--- |
| `XDG_CONFIG_HOME` | `~/.config` | Static configuration tree (symlinked from `config/`) |
| `XDG_CACHE_HOME` | `~/.cache` | Regenerable binary caches, AOT snapshots, SWR artifacts |
| `XDG_DATA_HOME` | `~/.local/share` | Persistent application state and databases |
| `XDG_STATE_HOME` | `~/.local/state` | Session logs, history buffers, runtime states |
| `XDG_BIN_HOME` | `~/.local/bin` | User-installed standalone binaries and utility shims |
| `XDG_RUNTIME_DIR` | `$TMPDIR` | Volatile runtime files, IPC sockets, ephemeral decrypted secrets |

*Zero dotfile pollution in `$HOME`. All configuration files live under deterministic XDG paths.*

---

## 10. References & Upstream Specifications

### Standards & Specifications
- [XDG Base Directory Specification v0.8+](https://specifications.freedesktop.org/basedir-spec/latest/)
- [POSIX IEEE Std 1003.1-2024](https://pubs.opengroup.org/onlinepubs/9799919799/)
- [SSH Signature Protocol (`PROTOCOL.sshsig`)](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.sshsig)
- [NIST Post-Quantum Cryptography Standards (FIPS 203 ML-KEM)](https://csrc.nist.gov/pubs/fips/203/final)

### Hardware Security & Cryptography
- [Secretive (Apple Secure Enclave SSH Agent)](https://github.com/maxgoedjen/secretive)
- [Mozilla SOPS (Secrets Operations)](https://github.com/getsops/sops)
- [age Encryption Tool](https://github.com/FiloSottile/age)

### Core Runtimes & Subsystems
- [Fish Shell Documentation](https://fishshell.com/docs/current/)
- [Ghostty Terminal](https://ghostty.org)
- [Tmux Terminal Multiplexer](https://github.com/tmux/tmux)
- [Neovim Documentation](https://neovim.io)
- [Mise Development Environment](https://mise.jdx.dev)
