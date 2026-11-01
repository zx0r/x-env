[![Platform](https://img.shields.io/badge/macOS-Apple_Silicon_arm64-black.svg)](#)
[![Shell](https://img.shields.io/badge/Shell-Fish_4.x-00ff41.svg)](#shell-architecture)
[![Subsystems](https://img.shields.io/badge/Subsystems-40-orange.svg)](#subsystem-registry)
[![XDG](https://img.shields.io/badge/XDG-Base_Directory-green.svg)](#xdg-layout)
[![Startup](https://img.shields.io/badge/Startup-7.6_ms-blue.svg)](#performance)

### XDG-compliant configuration files for a macOS developer workstation on Apple Silicon.

---

## Performance

### `hyperfine --warmup 10 -r 150 'fish -i -c exit'`

**Benchmark 1: `fish -i -c exit` (150 runs)**

| Metric | mean | σ | min | max |
| :--- | :---: | :---: | :---: | :---: |
| Wall Time [ms] | 7.4 | 0.5 | 6.6 | 8.5 |
| Memory [MiB] | 6.6 | 0.0 | 6.5 | 6.7 |

### `fish --profile-startup /tmp/fish.prof -ic exit && sort -nrk2 /tmp/fish.prof | head -20`

| Time (µs) | Sum (µs) | Command / Trace |
| :---: | :---: | :--- |
| 92 | 466 | `> for file in $__fish_config_dir/conf.d/*.fish $__fish_sysconf_dir/conf.d/*.fish $__fish_vendor_confdirs/*.fish...` |
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

## What This Is

A single Git repository that **is** `~/.config`. Every configuration file for every
CLI tool on the workstation lives here under `xdg/`, which gets symlinked to `~/.config/`.
Changes are version-controlled, diffable, and reproducible across machines.

```
~/x/config/xdg/  ──symlink──▶  ~/.config/
```

**Key properties:**

- **40 subsystems** configured: shells, terminals, editors, VCS, network tools, security
- **Zero dotfile pollution** in `$HOME` - everything lives under XDG paths
- **7.6 ms** interactive shell cold boot (0.6 ms over bare-metal hardware floor)
- **Post-quantum transport** - ML-KEM 768 (FIPS 203) across SSH and cURL
- **Hardware-rooted identity** — private keys in Apple Secure Enclave, Touch ID for auth

---

## Repository Layout

```
x-env/
├── fish/                         # Shell (primary)
├── kitty/                        # Kitty terminal
├── ghostty/                      # Ghostty terminal
├── alacritty/                    # Alacritty terminal
├── tmux/                         # Terminal multiplexer
├── starship/                     # Prompt
├── /xstory                       # Shell history
├── git/                          # Git
├── jj/                           # Jujutsu VCS
├── gh/                           # GitHub CLI
├── lazygit/                      # Git TUI
├── gitui/                        # Git TUI (alt)
├── gitleaks/                     # Secret leak scanner
├── ssh/                          # OpenSSH
├── curl/                         # cURL
├── wget/                         # wget
├── dnscrypt-proxy/               # Encrypted DNS
├── pf/                           # macOS firewall
├── nvim/                         # Neovim
├── bat/                          # Syntax-highlighted pager
├── ripgrep/                      # Search
├── yazi/                         # File manager
├── karabiner/                    # Keyboard remapper
├── btop/                         # System monitor
├── obsidian/                     # Knowledge base
├── pandoc/                       # Document converter
├── glow/                         # Markdown renderer
├── macos-security/               # mSCP compliance baselines
├── bob/                          # Neovim version manager
├── cocogitto/                    # Conventional commits
├── commitlint/                   # Commit linter
├── lefthook/                     # Git hooks
├── eslint/                       # JS linter
├── ruff/                         # Python linter
├── repomix/                      # Repo mixer
├── lazydocker/                   # Docker TUI
├── tig/                          # Git text-mode interface
├── hunk/                         # Diff viewer
├── git-graph/                    # Commit graph
├── colorsdb                      # Named color database
├── iconsdb                       # Nerd Font icon database
├── ls_colors                     # GNU LS_COLORS
└── eza_colors                    # Eza color overrides
```

---

## XDG Layout

All runtime state is isolated under [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/) paths:

| Variable          | Path             | What goes here                      |
| :---------------- | :--------------- | :---------------------------------- |
| `XDG_CONFIG_HOME` | `~/.config`      | Configuration (symlinked from xdg/) |
| `XDG_CACHE_HOME`  | `~/.cache`       | Regenerable caches, AOT snapshots   |
| `XDG_DATA_HOME`   | `~/.local/share` | Persistent application data         |
| `XDG_STATE_HOME`  | `~/.local/state` | Logs, history                       |
| `XDG_BIN_HOME`    | `~/.local/bin`   | User executables                    |
| `XDG_RUNTIME_DIR` | `$TMPDIR`        | Volatile runtime files              |

No dotfiles in `$HOME`. All directories created with `0700` permissions on first launch.

---

## Subsystem Registry

### Shell & Prompt

| Tool                                            | What it does                | Notes                                                                              |
| :---------------------------------------------- | :-------------------------- | :--------------------------------------------------------------------------------- |
| **[Fish](xdg/fish/)**                           | Primary interactive shell   | 85-line kernel; AOT snapshot; 96 functions; 222 abbreviations; 7.6 ms cold boot    |
| **[Starship](xdg/starship/)**                   | Cross-shell prompt          | Nerd Font glyphs; pre-compiled into AOT cache                                      |
| **[xstory](https://github.com/zx0r/xstory)**   | Shell history               | Rust; zero-copy mmap TSV; bitmask pruning; tree-sitter highlighting; <5 MB RAM      |
| **[FZF](xdg/fish/functions/__x_init_fzf.fish)** | Fuzzy finder                | Preview pipelines; Git integration; process management                             |

### Terminals

| Tool                             | Notes                                                                    |
| :------------------------------- | :----------------------------------------------------------------------- |
| **[Ghostty](xdg/ghostty/)**     | Primary GPU terminal; native macOS; Zig renderer                         |
| **[Kitty](xdg/kitty/)**         | Tab-bar plugin; dark-mode automation; split kitten; custom themes        |
| **[Alacritty](xdg/alacritty/)** | Minimal GPU terminal; Catppuccin & Gruvbox themes                        |

### Multiplexer

| Tool                   | Notes                                                                                                              |
| :--------------------- | :----------------------------------------------------------------------------------------------------------------- |
| **[Tmux](xdg/tmux/)** | Modular config; dual themes; FZF pane nav; status bar (CPU, RAM, SSD, net, git, uptime)                            |

### Version Control

| Tool                              | Notes                                                                     |
| :-------------------------------- | :------------------------------------------------------------------------ |
| **[Git](xdg/git/)**               | Touch ID commit signing (SSH sshsig); APFS normalization; FSEvents        |
| **[Jujutsu](xdg/jj/)**            | Git-compatible; operation log; conflict-first workflow                     |
| **[Lazygit](xdg/lazygit/)**       | Delta renderer; Neovim integration                                        |
| **[GitUI](xdg/gitui/)**           | Rust-based TUI                                                            |
| **[GitHub CLI](xdg/gh/)**         | API workflows; PR/issue management                                        |
| **[Gitleaks](xdg/gitleaks/)**     | Pre-commit leak detection                                                 |
| **[Cocogitto](xdg/cocogitto/)**   | Conventional commits; changelog generation                                |
| **[Commitlint](xdg/commitlint/)** | Commit message format enforcement                                         |
| **[Lefthook](xdg/lefthook/)**     | Git hook orchestration                                                    |

### Search & Navigation

| Tool                         | Notes                                                    |
| :--------------------------- | :------------------------------------------------------- |
| **[Ripgrep](xdg/ripgrep/)** | Global ignore patterns; custom options                   |
| **[Bat](xdg/bat/)**         | 17+ custom syntaxes; 300+ themes; man pager              |
| **Zoxide**                   | Frecency-based directory jumps; AOT cached               |
| **Eza**                      | Custom colors; Nerd Font icons; git status integration   |

### Network

| Tool                                      | Notes                                                                    |
| :---------------------------------------- | :----------------------------------------------------------------------- |
| **[cURL](xdg/curl/)**                     | HTTP/3; ML-KEM 768 TLS 1.3; AppleSecTrust; XDG-isolated caches          |
| **[wget](xdg/wget/)**                     | TLS 1.3 enforced; HSTS at absolute path; APFS xattr preservation        |
| **[DNSCrypt-Proxy](xdg/dnscrypt-proxy/)** | DoH/DNSCrypt encrypted DNS                                               |

### Security

| Tool                                      | Notes                                                                                |
| :---------------------------------------- | :----------------------------------------------------------------------------------- |
| **[SSH](xdg/ssh/)**                       | Post-quantum KEX (ML-KEM 768, sntrup761); AEAD ciphers; Secretive SEP integration   |
| **[pf](xdg/pf/)**                         | macOS Packet Filter firewall rules                                                   |
| **[macOS Security](xdg/macos-security/)** | NIST/CIS/DISA STIG baselines; automated audit                                        |
| **SOPS / age**                             | X25519 encryption; zero-disk-leak diffing; in-memory pipe decryption                 |
| **Secretive**                              | Apple Secure Enclave keys; Touch ID; non-exportable private keys                     |

### Editors & File Management

| Tool                           | Notes                                                                     |
| :----------------------------- | :------------------------------------------------------------------------ |
| **[Neovim](xdg/nvim/)**       | Version managed via Bob                                                   |
| **[Yazi](xdg/yazi/)**         | 17+ plugins; 13 themes; Starship integration                              |
| **[Obsidian](xdg/obsidian/)** | Vault configuration and plugin settings                                   |
| **[Pandoc](xdg/pandoc/)**     | Template library                                                          |
| **[Glow](xdg/glow/)**         | Terminal markdown viewer                                                  |

### System & Input

| Tool                                     | Notes                        |
| :--------------------------------------- | :--------------------------- |
| **[Karabiner-Elements](xdg/karabiner/)** | Keyboard remapping rules     |
| **[Btop](xdg/btop/)**                   | Resource monitor             |

### Color & Theme Data

| File                           | What it is                                     |
| :----------------------------- | :--------------------------------------------- |
| [`colorsdb`](xdg/colorsdb)     | Named color reference                          |
| [`iconsdb`](xdg/iconsdb)       | Nerd Font icon reference                       |
| [`ls_colors`](xdg/ls_colors)   | GNU LS_COLORS (trapd00r/LS_COLORS)             |
| [`eza_colors`](xdg/eza_colors) | Eza color overrides                            |

