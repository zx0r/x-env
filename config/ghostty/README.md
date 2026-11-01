# ⚡ GHOSTTY TERMINAL | PRINCIPAL ARCHITECT SPECIFICATION

> **High-Performance GPU-Accelerated Terminal Architecture for Apple Silicon (macOS)**
>
> Workspace: `zx0r` | Color Space: `Display P3` | Shell: `fish` | Multiplexer: `tmux` | Editor: `neovim`

---

## 📑 Table of Contents

1. [Architectural Philosophy: The Decoupled Stack](#-architectural-philosophy-the-decoupled-stack)
2. [The Kitty Paradox: Why Ghostty Wins on macOS](#-the-kitty-paradox-why-ghostty-wins-on-macos)
3. [Liquid Retina XDR: Full-Perimeter Notch Architecture](#-liquid-retina-xdr-full-perimeter-notch-architecture)
4. [Hardware & Metal Rendering Calibration](#-hardware--metal-rendering-calibration)
5. [Tmux Integration & Protocol Passthrough Pipeline](#-tmux-integration--protocol-passthrough-pipeline)
6. [Keyboard Matrix & Zero-Conflict Authority](#-keyboard-matrix--zero-conflict-authority)
7. [Typography & Subpixel Glyph Shaper](#-typography--subpixel-glyph-shaper)

---

## 🏛 Architectural Philosophy: The Decoupled Stack

This workstation configuration is governed strictly under the **Single Responsibility Principle (SRP)** at the operating system tier:

> **"Tmux manages sessions, Neovim manages code, and the terminal is strictly a pure GPU-renderer."**
>
> On macOS, this triad makes Ghostty the engineering pinnacle. Kitty in this configuration is redundant.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. PRESENTATION LAYER : GHOSTTY (Zig Core + Swift/AppKit + Pure Metal)      │
│    120Hz ProMotion Frame Pacing | Liquid Retina Notch Wrap | CoreText Engine│
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Raw PTY / CSI u / OSC 52 / Graphics
┌──────────────────────────────────────▼──────────────────────────────────────┐
│ 2. SESSION & WORKSPACE LAYER : TMUX (Multiplexer Orchestrator)              │
│    Persistent Daemon | Split Topologies | Session Attach/Detach | Sockets   │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ AST Buffers / LSP / Virtual Text
┌──────────────────────────────────────▼──────────────────────────────────────┐
│ 3. APPLICATION & BUFFER LAYER : NEOVIM (Editor Engine)                      │
│    Treesitter Syntax | Language Servers | Telescope / Snacks Fuzzy Finders  │
└─────────────────────────────────────────────────────────────────────────────┘
```

When session state, persistence, and window splitting are delegated to Tmux, the terminal emulator no longer needs to be an "operating system inside an operating system." Its singular objective is to be the fastest, lowest-latency, and most hardware-integrated GPU canvas available.

---

## ⚖️ The Kitty Paradox: Why Ghostty Wins on macOS

Kitty pioneered modern terminal protocol engineering (Kitty Graphics Protocol, extended keyboard specification, remote control IPC). However, Kitty's architectural philosophy is built around self-contained multiplexing: native OS windows, native tabs, custom splits, and an embedded Python runtime.

When an engineer uses Tmux as their primary workspace multiplexer, Kitty's model introduces architectural duplication:
* **Duplicated Abstractions:** Two independent tab systems, two split engines, and overlapping shortcut layers competing for keystrokes.
* **GLFW Abstraction Tax:** Kitty renders via OpenGL through GLFW. On macOS, OpenGL is deprecated and executed through Apple's translation shim, increasing power draw and introducing minor frame-pacing variances.

### The Ghostty Dual-Layer Advantage
Ghostty separates headless terminal emulation from platform rendering:
* **Engine Core:** Written in **Zig** for deterministic memory control, zero-overhead allocations, and raw ANSI processing speed.
* **macOS Frontend:** Written in **native Swift/AppKit**, speaking directly to Cocoa WindowServer and **Apple Metal**.
* **Zero Cognitive Friction:** Ghostty yields all multiplexing authority to Tmux, focusing 100% of Apple Silicon GPU resources on instantaneous glyph rasterization and ProMotion synchronization.

---

## 💻 Liquid Retina XDR: Full-Perimeter Notch Architecture

By default, macOS enforces synthetic letterboxing in native full-screen mode: the active space is pushed down below the camera housing, and the surrounding auxiliary areas ("ears") are blanked out with a solid black bar.

This configuration bypasses macOS letterbox latency entirely using non-native AppKit presentation overrides:

```
                  [ 100% PHYSICAL DISPLAY CANVAS ]
┌───────────────────────────────────┬───────────────────────────────────┐
│     AUXILIARY TOP-LEFT ("EAR")    │ █ CAMERA NOTCH █ │    AUXILIARY TOP-RIGHT ("EAR")    │
├───────────────────────────────────┴──────────────────┴───────────────────┤
│                                                                           │
│                      GHOSTTY ZERO-LATENCY CANVAS                          │
│                    (macos-non-native-fullscreen = true)                   │
│                                                                           │
└───────────────────────────────────────────────────────────────────────────┘
```

### Manifest Directives ([`config.ghostty`](file:///Users/x0r/.config/ghostty/config.ghostty))
* `fullscreen = true`: Windows automatically spawn in full-screen mode without requiring manual hotkeys.
* `macos-non-native-fullscreen = true`: Bypasses Spaces animation, expanding the window frame to the exact physical pixel boundary (`NSScreen.frame`) and flowing into the display ears around the camera notch.
* `macos-titlebar-style = hidden` & `macos-window-buttons = hidden`: Eliminates titlebar chrome and traffic lights.
* `window-decoration = false`: Pure borderless canvas without desktop margins.

---

## ⚡ Hardware & Metal Rendering Calibration

* **Graphics Backend:** Native Apple Metal Pipeline.
* **Frame Synchronization:** `window-vsync = true` locks rendering to the display refresh cycle via `CVDisplayLink` (native 120Hz ProMotion), eliminating screen tearing and idling threads when idle.
* **Color Space Fidelity:** `window-colorspace = display-p3` provides unconstrained Wide Gamut rendering calibrated for Liquid Retina XDR.
* **Material Compositing:** `background-opacity = 0.60` with `background-blur = 25` and hardware-accelerated linear gamma correction (`alpha-blending = linear-corrected`).

---

## 🔗 Tmux Integration & Protocol Passthrough Pipeline

Ghostty and Tmux operate as a single coordinated system via explicit capability contracts:

### 1. Kitty Graphics Protocol Passthrough
Ghostty implements the Kitty Graphics Protocol natively. In [`~/.config/tmux/config/core.conf`](file:///Users/x0r/.config/tmux/config/core.conf), passthrough is enabled globally:
```tmux
set -g allow-passthrough all
```
High-resolution images in `yazi`, markdown image previews, and `snacks.nvim` render directly within Tmux panes with zero degradation.

### 2. OSC 52 Native Clipboard Bridge
Bidirectional system clipboard synchronization operates over ANSI escape sequences without external CLI shims:
* Ghostty configuration: `clipboard-write = allow` and `clipboard-read = ask`.
* Tmux configuration: `set -s set-clipboard on`.
Text copied in Tmux copy-mode synchronizes instantly into the macOS pasteboard.

### 3. Cursor Shapes & Extended Keyboard (`CSI u`)
```tmux
set -s terminal-features[3] 'xterm-ghostty:RGB:extkeys:hyperlinks:cstyle:usstyle:overline:strikethrough:bpaste'
```
* **Dynamic Cursor Styling (`cstyle`):** Seamless transitions between Block (Normal), Beam (Insert), and Underline (Replace) inside Neovim.
* **Key Disambiguation (`extkeys`):** Accurate resolution of modifier combinations (`Shift+Enter`, `Ctrl+Enter`, `Ctrl+I` vs `Tab`).
* **Semantic Hyperlinks (`hyperlinks`):** Native OSC 8 clickable links from `git`, `delta`, and `ripgrep`.

---

## ⌨️ Keyboard Matrix & Zero-Conflict Authority

In [`keymaps/binds.ghostty`](file:///Users/x0r/.config/ghostty/keymaps/binds.ghostty), conflicting terminal-level shortcuts are explicitly neutralized so Tmux retains sole multiplexing authority:

```ghostty
# Releases native GUI shortcuts so Tmux retains sole multiplexing authority:
keybind = super+d=unbind
keybind = super+shift+d=unbind
keybind = ctrl+shift+enter=unbind
```

### Window Geometry & State Controls

| Keybinding | Action | Functional Description |
| :--- | :--- | :--- |
| <kbd>Cmd</kbd>+<kbd>Enter</kbd> | `toggle_fullscreen` | Instant Full-Perimeter Notch canvas (zero-latency non-native toggle) |
| <kbd>Cmd</kbd>+<kbd>Ctrl</kbd>+<kbd>F</kbd> | `toggle_fullscreen` | Standard macOS full-screen toggle counterpart |
| <kbd>Cmd</kbd>+<kbd>Ctrl</kbd>+<kbd>M</kbd> | `toggle_maximize` | Maximizes window bounds within standard desktop borders |
| <kbd>Cmd</kbd>+<kbd>Alt</kbd>+<kbd>D</kbd> | `toggle_window_decorations` | Dynamically shows/hides titlebar and window controls |
| <kbd>Cmd</kbd>+<kbd>`</kbd> | `toggle_quick_terminal` | Global Quake-style drop-down HUD terminal |

---

## 🖋 Typography & Subpixel Glyph Shaper

* **Primary Font:** `Maple Mono NF` ([`fonts/maple.ghostty`](file:///Users/x0r/.config/ghostty/fonts/maple.ghostty))
* **Font Size:** `font-size = 13.5`
* **OpenType Features:** `+calt` (contextual programming ligatures), `+zero` (slashed zero)
* **Codepoint Mapping:** Explicit fallbacks for Symbols Nerd Font (`U+E000-U+E0C8`, `U+23FB-U+23FE`) to preserve cell aspect ratios.
* **Text Shaper:** Native macOS CoreText shaper with 8-bit grayscale anti-aliasing.
