# Tmux Configuration

Modular, declarative configuration for Tmux with zero-fork Neovim split navigation, floating modal
popups, and isolated runtime scripts.

---

## Environment Baseline

All platform and runtime assumptions are consolidated here.

| Component         | Target / Tested                            | Notes                                                   |
| ----------------- | ------------------------------------------ | ------------------------------------------------------- |
| **OS**            | macOS 15+ (Apple Silicon)                  | Compatible with Linux x86_64/arm64                      |
| **Shell**         | Fish 3.7+                                  | Default shell at `/opt/homebrew/bin/fish`               |
| **Terminal**      | Kitty / Ghostty / Alacritty                | Requires 24-bit TrueColor (`RGB`) & CSI u extended keys |
| **Multiplexer**   | Tmux 3.7+                                  | Requires `display-popup` support                        |
| **CLI Utilities** | `fzf`, `zoxide`, `yazi`, `lazygit`, `btop` | Used by floating modal overlays                         |

---

## Directory Structure

In accordance with XDG Base Directory specification, configuration is strictly decoupled from
executable runtime files.

```plaintext
~/.config/tmux/                     # Static Declarative Configuration Root
├── config/                         # Modular Subsystem Configurations
│   ├── binds.conf                  # Keybindings & Navigation Engine
│   ├── core.conf                   # Server, Terminal Features, Mouse, Buffer Settings
│   ├── hooks.conf                  # Pane Border Hooks & Session Lifecycle Events
│   ├── plugins.conf                # TPM Plugins & External Tool Binds
│   └── theme.conf                  # Status Bar Layout & Color Definitions
├── docs/                           # Documentation
│   └── NAVIGATION_ARCHITECTURE.md  # Detailed Navigation Specification
├── modes/                          # Context Modes (loaded via $X_MODE)
│   ├── agent.tmux                  # Agentic / PTY Mode
│   └── human.tmux                  # Interactive Terminal Mode
├── stages/                         # Environmental Stages (loaded via $X_STAGE)
│   ├── dev.tmux                    # Development Stage
│   ├── staging.tmux                # Staging Stage
│   └── prod.tmux                   # Production Stage
├── theme/                          # Color Palettes
│   ├── dark.tmux                   # Dark Color Tokens
│   └── light.tmux                  # Light Color Tokens
├── README.md                       # System Documentation
└── tmux.conf                       # Main Orchestrator & Bootloader

~/.local/bin/tmux/                  # Executable Runtime Infrastructure ($XDG_BIN_HOME/tmux)
├── fzf-panes.sh                    # Optional Legacy Pane Selector Script
└── ai/
    └── ai-prompt-edit.sh           # Prompt Editor Launcher (Neovim/fzf)
```

---

## Initialization Layers

The main entry point [`tmux.conf`](file:///Users/x0r/.config/tmux/tmux.conf) executes four
initialization steps:

1. **Layer I (Bootstrap):** Resolves `$XDG_CONFIG_HOME` and `$XDG_BIN_HOME`. Injects format-expanded
   path variables (`@config`, `@scripts`).
2. **Layer II (Module Router):** Sequentially sources `core.conf`, `binds.conf`, `hooks.conf`,
   `theme.conf`, and `plugins.conf`.
3. **Layer III (Environment Sync):** Synchronizes terminal and tool variables (`COLORTERM`,
   `TERM_PROGRAM`, `KITTY_PID`, `NVIM_NOTTYFAST`, etc.).
4. **Layer IV (Operational Router):**
   - Injects `modes/$X_MODE.tmux` (defaults to `modes/human.tmux`).
   - Injects `stages/$X_STAGE.tmux` (defaults to `stages/dev.tmux`).

---

## Key Bindings Reference

The prefix key is `Ctrl+a`. To send literal `Ctrl+a` to the shell, press `Ctrl+a Ctrl+a`.

### Panes & Splits

| Action                  | Root (No Prefix) | Prefix (`Ctrl+a`)        | Behavior                                        |
| ----------------------- | ---------------- | ------------------------ | ----------------------------------------------- |
| **Neovim / Tmux Left**  | `Ctrl + h`       | `prefix h`               | Focuses left split; passes to Neovim if active  |
| **Neovim / Tmux Down**  | `Ctrl + j`       | `prefix j`               | Focuses down split; passes to Neovim if active  |
| **Neovim / Tmux Up**    | `Ctrl + k`       | `prefix k`               | Focuses up split; passes to Neovim if active    |
| **Neovim / Tmux Right** | `Ctrl + l`       | `prefix l`               | Focuses right split; passes to Neovim if active |
| **Previous Split**      | `Ctrl + \`       | `prefix ;`               | Selects previously active pane                  |
| **Split Horizontal**    | —                | `prefix -` / `prefix s`  | Splits pane top/bottom in current path          |
| **Split Vertical**      | —                | `prefix \|` / `prefix v` | Splits pane left/right in current path          |
| **Full Edge Splits**    | —                | `prefix \` / `prefix _`  | Full-height column or full-width row split      |
| **Toggle Zoom**         | —                | `prefix z` / `prefix /`  | Toggles full-screen pane zoom                   |
| **Micro Resize**        | `Alt + Arrows`   | —                        | Resizes active pane by 3–5 cells                |
| **Macro Resize**        | —                | `prefix H / J / K / L`   | Repeatable pane resize steps                    |
| **Equalize Layout**     | —                | `prefix =` / `prefix E`  | Balances panes evenly                           |
| **Break / Join Pane**   | —                | `prefix !` / `prefix @`  | Break to new window / join from target          |
| **Kill Pane**           | —                | `prefix x`               | Closes active pane                              |
| **Clear Screen**        | —                | `prefix C-l`             | Sends literal `Ctrl+L` to shell                 |

### Windows

| Action                     | Root (No Prefix)      | Prefix (`Ctrl+a`)       | Behavior                                     |
| -------------------------- | --------------------- | ----------------------- | -------------------------------------------- |
| **Previous / Next Window** | `Alt + h` / `Alt + l` | `prefix p` / `prefix n` | Switches tab (auto-creates if only 1 window) |
| **Direct Jump (1–9)**      | `Alt + 1 .. 9`        | `prefix 1 .. 9`         | Switches directly to window 1–9              |
| **Last Active Window**     | `Alt + w`             | `prefix BSpace`         | Toggles back to previously focused window    |
| **New Window (Adjacent)**  | —                     | `prefix c`              | Creates window after current in working dir  |
| **New Window (At End)**    | —                     | `prefix C`              | Creates window at end in working dir         |
| **Swap Window Position**   | —                     | `prefix <` / `prefix >` | Moves window left/right, keeps focus         |
| **Rename Window**          | —                     | `prefix ,` / `prefix A` | Renames active window                        |
| **Kill Window**            | —                     | `prefix &`              | Closes window (prompts confirmation)         |

### Sessions & Workspaces

| Action                   | Root (No Prefix) | Prefix (`Ctrl+a`)           | Behavior                                             |
| ------------------------ | ---------------- | --------------------------- | ---------------------------------------------------- |
| **Workspace Selector**   | `Alt + s`        | `prefix Space` / `prefix s` | Opens `tmx` fuzzy session manager in popup           |
| **Toggle Last Session**  | `Alt + Tab`      | `prefix Tab`                | Switches to previously active session                |
| **Cycle Sessions**       | —                | `prefix (` / `prefix )`     | Cycles previous/next session                         |
| **Session Tree**         | —                | `prefix S`                  | Interactive session tree (`choose-tree -Zs`)         |
| **New Session**          | —                | `prefix C-c`                | Prompts for new session name                         |
| **Rename Session**       | —                | `prefix R`                  | Renames current session                              |
| **Kill Current Session** | —                | `prefix X`                  | Terminates active session (prompts confirmation)     |
| **Kill Other Sessions**  | —                | `prefix Q`                  | Terminates all other sessions (prompts confirmation) |

### Floating Modal Overlays (Popups)

Modals run in centered floating popups without altering the 2D pane layout.

| Tool                   | Root (No Prefix) | Prefix (`Ctrl+a`) | Command / Behavior                             |
| ---------------------- | ---------------- | ----------------- | ---------------------------------------------- |
| **FZF Pane Navigator** | `Alt + f`        | `prefix w`        | Interactive pane search with live ANSI preview |
| **Lazygit**            | `Alt + g`        | `prefix g`        | Git TUI in current pane path                   |
| **Yazi**               | `Alt + y`        | `prefix y`        | File manager in current pane path              |
| **Btop**               | `Alt + b`        | `prefix b`        | Process and system monitor                     |
| **AI Workspace**       | `Alt + a`        | `prefix a`        | AI CLI selector (`tmx-ai --internal`)          |
| **AI Prompt Editor**   | `Ctrl + e`       | `prefix M-e`      | Author prompt in Neovim, paste to pane         |
| **Scratchpad Shell**   | `Alt + '`        | `prefix '`        | Dedicated persistent floating shell            |

### Copy Mode & Buffers

| Action                   | Shortcut                        | Behavior                                               |
| ------------------------ | ------------------------------- | ------------------------------------------------------ |
| **Enter Copy Mode**      | `prefix Enter` or `prefix [`    | Enters Vi copy mode                                    |
| **Begin Selection**      | `v` (in copy mode)              | Starts character selection                             |
| **Line Selection**       | `V` (in copy mode)              | Starts line selection                                  |
| **Block Selection**      | `Ctrl + v` or `Alt + MouseDrag` | Toggles rectangle selection                            |
| **Yank to Clipboard**    | `y` or `MouseDragEnd`           | Copies to system clipboard via `pbcopy` and OSC 52     |
| **Word Search**          | `*` / `#` (in copy mode)        | Searches forward/backward for word under cursor        |
| **Paste Buffer**         | `prefix p`                      | Pastes top buffer                                      |
| **Scrollback in Neovim** | `prefix M-c`                    | Dumps 100k lines of scrollback into Neovim             |
| **Session Telemetry**    | `prefix i`                      | Displays session uptime, window count, and client info |
| **Command Palette**      | `prefix C-p`                    | Categorized interactive action menu                    |
| **Reload Config**        | `prefix r`                      | Reloads `tmux.conf` without closing sessions           |

---

## Window Workflow Pattern

Project sessions follow a 3-window:

- **Window 1 (Dev):**
- **Window 2 (Ops):**
- **Window 3 (Run):**
