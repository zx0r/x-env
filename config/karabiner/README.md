# ⌨️ Karabiner-Elements Systems Architecture & Keymap Engine

High-performance, ergonomic keyboard configuration profile and modular build pipeline for **macOS Apple Silicon**, featuring hardware integration for the **Royal Kludge RK H81** (75% mechanical layout) and the internal MacBook Pro keyboard.

Designed for systems engineering, Neovim/modal editing, GPU terminal multiplexing, and zero-conflict macOS application orchestration.

---

## 🛠️ Technology & Hardware Stack

* **Operating System:** macOS Apple Silicon (ARM64)
* **Virtual HID Engine:** [Karabiner-Elements](https://karabiner-elements.pqrs.org/) 16.3.0 (DriverKit VirtualHIDDevice 1.8.0)
* **Primary Terminal:** [Ghostty](https://ghostty.org/) (Metal GPU pipeline)
* **Secondary Terminal:** [Kitty Terminal](https://sw.kovidgoyal.net/kitty/)
* **Application Launcher:** [Raycast](https://www.raycast.com/)
* **Hardware Peripherals:**
  * **Royal Kludge RK H81** (Bluetooth Low Energy 5.0 / USB-C wired / 2.4G)
  * **MacBook Pro Liquid Retina XDR** Internal Keyboard & Trackpad

---

## ⚡ 30-Second Rapid Deployment on a Fresh Mac

Deploy this exact workstation state to any new macOS machine:

```bash
# 1. Install Karabiner-Elements
brew install --cask karabiner-elements

# 2. Clone / copy configuration to ~/.config/karabiner

# 3. Run the Deep Merge compiler
python3 ~/.config/karabiner/scripts/build_config.py
```

The compiler will:
1. Introspect active HID hardware via DriverKit API.
2. Compile and lint all 6 modules against `karabiner_cli`.
3. Apply `0ms` Caps Lock debounce and optimal 250ms dual-role latency.
4. Atomically activate `Developer Profile` in the background daemon.

---

## 🚀 Keymap Matrix & Ergonomic Layers

### 1. Dual-Role Caps Lock: Hyper Key & Escape
* **Tap (<250ms):** `Escape` (Instant Vim/Neovim modal escape).
* **Hold:** **`Hyper Key`** (`Cmd + Ctrl + Option + Shift`).
* **Latency Optimization:** DriverKit debouncing delay is forced to `0ms` (`caps_lock_delay_milliseconds: 0`).

---

### 2. Full Home-Row Vim Navigation & Selection
Hold **`Caps Lock (Hyper)`** to access the complete cursor manipulation matrix:

| Shortcut | Mapped Output | Action Description |
| :--- | :--- | :--- |
| **`Hyper + H`** | `Left Arrow` | Character left |
| **`Hyper + J`** | `Down Arrow` | Line down |
| **`Hyper + K`** | `Up Arrow` | Line up |
| **`Hyper + L`** | `Right Arrow` | Character right |
| **`Hyper + W`** | `Option + Right Arrow` | Forward word jump |
| **`Hyper + B`** | `Option + Left Arrow` | Backward word jump |
| **`Hyper + 0`** / **`Hyper + A`** | `Command + Left Arrow` | Beginning of line (Home) |
| **`Hyper + $ (4)`** / **`Hyper + E`** | `Command + Right Arrow` | End of line (End) |
| **`Hyper + U`** | `Page Up` | Scroll page up |
| **`Hyper + D`** | `Page Down` | Scroll page down |
| **`Hyper + I`** | `Command + Up Arrow` | Document start |
| **`Hyper + O`** | `Command + Down Arrow` | Document end |
| **`Hyper + X`** | `Backspace` | Backward character delete |
| **`Hyper + Shift + H/J/K/L`** | `Shift + Arrow` | Home-row text selection |
| **`Hyper + Shift + W/B`** | `Shift + Option + Arrow` | Word-by-word text selection |

---

### 3. Zero-Conflict Application & Window Orchestration
Eliminates dangerous global hooks that hijack form submissions (`Cmd+Enter`) or IDE quick fixes (`Option+Enter`):

| Shortcut | Target Process | Action |
| :--- | :--- | :--- |
| **`Hyper + Return`** | **Ghostty** | Instant focus / launch primary terminal |
| **`Hyper + Shift + Return`** | **Kitty** | Instant focus / launch secondary terminal |
| **`Hyper + Grave (`)`** | **Ghostty HUD** | Toggle global Quake drop-down terminal |
| **`Hyper + Space`** | **Raycast** | Instant system launcher |
| **`Hyper + C`** | **Raycast Clipboard** | Instant clipboard history search |
| **`Hyper + F`** | **Raycast Files** | Instant file search |
| **`Hyper + S`** | **Safari** | Focus or launch browser |
| **`Hyper + M`** | **Apple Mail** | Focus or launch email client |

---

### 4. Window Snapping & Multi-Display Management (Raycast Native)
Instant window layout orchestration via native Raycast deeplinks (no third-party window managers required):

| Shortcut | Target Process / Deep Link | Action Description |
| :--- | :--- | :--- |
| **`Hyper + Left Arrow`** | `raycast/.../left-half` | Snap active window to left half |
| **`Hyper + Right Arrow`** | `raycast/.../right-half` | Snap active window to right half |
| **`Hyper + Up Arrow`** | `raycast/.../maximize` | Maximize active window |
| **`Hyper + Down Arrow`** | `raycast/.../center` | Center active window |
| **`Hyper + Shift + Left Arrow`** | `raycast/.../previous-display` | Throw active window to previous display |
| **`Hyper + Shift + Right Arrow`** | `raycast/.../next-display` | Throw active window to next display |
| **`Hyper + Shift + Up Arrow`** | `raycast/.../almost-maximize` | Almost maximize window (margins preserved) |
| **`Hyper + Shift + Down Arrow`** | `raycast/.../reasonable-size` | Restore reasonable default size |

#### Home-Row Window Placement (Vim Chords with Right-Option):
| Shortcut | Action Description |
| :--- | :--- |
| **`Hyper + Right Option + H`** | Snap window to left half |
| **`Hyper + Right Option + L`** | Snap window to right half |
| **`Hyper + Right Option + K`** | Maximize active window |
| **`Hyper + Right Option + J`** | Center active window |
| **`Hyper + Right Option + N`** | Move window to next display |
| **`Hyper + Right Option + P`** | Move window to previous display |
| **`Hyper + Right Option + M`** | Almost maximize window |

---

### 5. Zero-Latency Language Switching
* **Tap `Right Shift` or `Right Control` (<250ms):** Toggles input language (sends `Ctrl + Space`).
* **Hold `Right Shift` or `Right Control`:** Functions natively as Shift/Control with 0ms buffering delay.

---

### 6. System Safety Guard: Accidental Quit Protection
* **Tapping `Cmd + Q`:** Keypress is swallowed to prevent accidental loss of IDE, terminal, or browser tabs.
* **Holding `Cmd + Q` (>600ms):** Dispatches native application quit.

---

### 7. Royal Kludge RK H81 Hardware Integration
* **Command ↔ Option Swap:** Automatically maps physical keys to Mac order when keyboard is in Windows layout mode (`Fn + A`), ensuring physical `Alt` behaves as `Command` and `Win` as `Option`.
* **Hardware Isolation:** Scoped strictly via `device_if` to RK H81 (`vendor_id: 13652:64007` and `1240:61138`); internal MacBook keyboard is unaffected.
* **Function Row:** Direct access to native macOS brightness, Mission Control, Launchpad, media controls, and volume without holding Fn.

---

### 8. Raycast Script Commands (High-Performance Dev Automation)
Autonomous shell utilities integrated into Raycast via `~/.config/raycast/commands/`:

| Script Command | Trigger / Mode | Package | Functionality |
| :--- | :--- | :--- | :--- |
| **`kill-port.sh`** | Compact (`⚡️`) | Developer Utilities | Terminates any process on target TCP port (e.g. `:3000`, `:8080`) with graceful `SIGTERM` → `SIGKILL` escalation. |
| **`active-ports.sh`** | Full Output (`📡`) | Developer Utilities | Renders a clean ASCII table of all active local TCP listening sockets, PIDs, processes, and users. |
| **`tmux-session.sh`** | Compact (`💻`) | Developer Utilities | Instant tmux session manager. Attaches or spawns a session (e.g. `rt`, `dev`) and brings Ghostty to focus. |
| **`gh-review.sh`** | Full Output (`🐙`) | Developer Utilities | Interactive GitHub PR review triage filter (`review`, `assigned`, `author`) via `gh` CLI. |
| **`inbox-capture.sh`** | Compact (`🧠`) | Second Brain | Sub-second capture appending timestamped notes directly into Obsidian Inbox (`~/x/brain/00_inbox/_inbox.md`). |

> [!TIP]
> **To activate scripts in Raycast:** Open *Raycast Settings (`Cmd + ,`) → Extensions → Add Script Directory* and select `~/.config/raycast/commands`.

---

## 🌐 Hardware Compatibility & Portability Matrix

Will this setup work out-of-the-box on ANY Mac with ANY keyboard? **Yes for 90% of the architecture, with one hardware-level distinction for external keyboards:**

| Hardware Target | Examples | Out-of-the-Box Behavior | Action Required |
| :--- | :--- | :--- | :--- |
| **Built-in MacBook Keyboard** | MacBook Pro / Air (Apple Silicon M1–M4 / Intel) | **100% Plug & Play.** Hyper key, Vim navigation, app launchers, language switcher, and 0ms debounce work immediately. | None. |
| **Mac-Compatible External (Type 1)** | Apple Magic Keyboard, Keychron (Mac mode), NuPhy, RK H81 (`Fn + S`) | **100% Plug & Play.** Key adjacent to spacebar already emits `Command` in firmware. | None. Connect via Bluetooth or USB. |
| **Generic PC/Windows Keyboards (Type 2)** | Dell, HP, Corsair, standard mechanical keyboards (`Ctrl-Win-Alt`) | Core engine (Modules 01–05, 07) works perfectly. However, physical `Alt` emits PC `Alt` instead of `Command`. | Switch hardware toggle to Mac mode **OR** swap Modifier Keys in *System Settings → Keyboard*. |

> [!NOTE]
> Hardware swaps in `06_rk_h81_hardware.json` are isolated via `device_if` to external controller vendor IDs (`13652:64007` and `1240:61138`), guaranteeing that the built-in MacBook keyboard is **never** affected.

---

## 📂 Modular Architecture & Build Pipeline

Configurations are maintained as isolated modules in `assets/complex_modifications/` and compiled into `karabiner.json`:

```
~/.config/karabiner/
├── README.md                          # Operator documentation
├── karabiner.json                     # Compiled production configuration
├── docs/
│   └── ARCHITECTURE.md                # In-depth systems engineering reference
├── scripts/
│   └── build_config.py                # Build, lint & deployment compiler
├── assets/
│   └── complex_modifications/
│       ├── 01_hyper_caps_lock.json    # Caps Lock dual-role (Hyper / Escape)
│       ├── 02_vim_navigation.json     # Vim navigation & selection
│       ├── 03_app_launcher.json       # Ghostty, Kitty, Raycast orchestration
│       ├── 04_language_toggle.json    # Language switcher
│       ├── 05_system_safety.json      # Hold Cmd+Q to quit
│       ├── 06_rk_h81_hardware.json    # RK H81 hardware layer
│       └── 07_window_management.json  # Raycast window snapping & display hopping
└── automatic_backups/                 # Pristine baseline & configuration snapshots
```

### CLI Operations:

1. **Compile & Apply Configuration:**
   ```bash
   python3 scripts/build_config.py
   ```
2. **Lint All Complex Modifications:**
   ```bash
   python3 scripts/build_config.py --lint
   ```
3. **Verify Active Live Profile via Karabiner CLI:**
   ```bash
   /Library/Application\ Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli --show-current-profile-name
   ```
