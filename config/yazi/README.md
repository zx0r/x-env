# ⚡YAZI TERMINAL ARCHITECTURE SPECIFICATION

> **Theme:** `x`
> **Aesthetic:** High-Voltage Cyberpunk / Void Obsidian
> **Target Engine:** Yazi v26.x (Homebrew / aarch64-apple-darwin)
> **Paradigm:** System-as-Interface | Zero Friction | High Velocity
> **Role:** Principal macOS Platform Architect & Lead UX Engineer

---

## 1. Executive Summary & Paradigm: "X Workspace"

**X Workspace** is a reference-grade engineering workstation environment for filesystem navigation
and codebase exploration, engineered under strict **Zero Cognitive Friction** and high-density
terminal aesthetics.

Yazi functions as a **high-throughput Developer Dispatcher**:

1. **Zero Latency:** Asynchronous Rust runtime coupled with Kitty Graphics Protocol (`Kgp`), native
   FZF, Ripgrep, Neovim, and Git telemetry.
2. **Deterministic Modal Ergonomics:** Instant atomic file selection on `<Space>` (zero which-key
   collision), range selection via Visual Mode (`v` / `V`), and a dedicated Leader Key Matrix under
   `,` (with `\` alias) for instant tool dispatch.
3. **Visual Semantics:** High-contrast palette synchronized with `x.lua` / `master.lua`,
   distinguishing file classifications, Git states, and Unix permissions.

---

## 2. Color System: "x" Theme (Total Transparency & x.lua Identity)

Synchronized with Neovim design tokens (`~/.config/nvim/zx0r/colors/x.lua` and
`lua/theme/master.lua`). Implements the **Total Transparency Architecture** (`bg = NONE / reset`) to
eliminate visual noise and heavy background slabs.

| Token                 | HEX                       | Semantic Purpose                 | Yazi UI Elements                                    |
| :-------------------- | :------------------------ | :------------------------------- | :-------------------------------------------------- |
| **bg**                | `NONE / reset`            | Terminal background preservation | Panel background, header, inputs, picker            |
| **hover / selection** | `fg = #00FFFF, underline` | High-contrast cursor focus       | Active cursor hover, inputs, which-key candidates   |
| **cyan**              | `#00FFFF`                 | Primary system accent            | Cursor indicator, directories, `[normal]`, CWD      |
| **magenta**           | `#CD00F7`                 | Visual selection & keywords      | `[select]` mode, Untracked Git, SQL, visual markers |
| **purple**            | `#A855F7`                 | Architecture & data types        | `[unset]` mode, Rust (`*.rs`), TOML/YAML configs    |
| **pink**              | `#F40091`                 | Functions & operations           | Video files, Mermaid diagrams, operations           |
| **green**             | `#00B800`                 | Success & executables            | Staged Git, Executables (`+x`), Markdown, Shell     |
| **yellow**            | `#FFFF00`                 | Warnings & modifications         | Modified Git, Python/JS, JSON, numbers              |
| **orange**            | `#FF8C00`                 | Archives & constants             | Archives (7z/zip/tar), boolean values               |
| **red**               | `#FF0000`                 | Errors & removals                | Deleted Git, runtime errors, cut markers            |
| **blue**              | `#0A84FF`                 | Documentation & symlinks         | LaTeX (`*.tex`), active tabs, symlinks              |
| **text**              | `#BCC4DD`                 | Primary typographical text       | Filenames, input values, hints                      |
| **muted**             | `#97A0BC`                 | Secondary text                   | File timestamps, inactive items                     |
| **dim**               | `#646B84`                 | Comments & inactive UI           | Inactive tabs, permission masks, comments           |
| **border_dim**        | `#5D6480`                 | Subtle hairline borders          | Border frames (`full-border`), dividers             |

---

## 3. Plugin Architecture & Preview Pipeline

Packages are managed declaratively via Yazi Package Manager (`ya pkg`):

```
~/.config/yazi/
├── yazi.toml        # Core settings, openers, which-key rules, preview pipelines
├── keymap.toml      # Reference keymap matrix (Zero-conflict Space selection + Leader matrix)
├── theme.toml       # "x" Theme styling (Total Transparency + which-key UI + x.tmTheme)
├── init.lua         # Lua runtime, telemetry statusline, and component hooks
├── package.toml     # Package declarations for ya pkg
└── plugins/         # Native and community plugins
```

### Preview Pipeline:

1. **`bat.yazi`**: High-speed code, config, and LaTeX (`*.tex`, `*.bib`) syntax highlighting via
   `bat --theme=x`.
2. **`mermaid.yazi`**: Offline rendering of Mermaid diagrams (`*.mmd`, `*.mermaid`) and inline
   Markdown diagrams using `mmdc` (Mermaid CLI) with 2x Retina scale.
3. **`glow.yazi` / `piper.yazi`**: Full-width TrueColor Markdown previewer.
4. **`git-root.yazi`**: Instant navigation to Git repository root (`g r`).
5. **`git.yazi`**: Background Git status linemode indicators.
6. **`diff.yazi`**: Interactive diff comparison (selected vs hovered).
7. **`chmod.yazi`**: TUI Unix permission mask editor.
8. **`full-border.yazi`**: Minimal rounded hairline frame.
9. **`smart-enter.yazi`**: Contextual entry: directory drill-down vs Neovim file open.
10. **`toggle-pane.yazi`**: Instant maximize/restore for preview pane (`T` or `, ,`).
11. **`bookmarks.yazi`**: Persistent directory bookmarks via Yazi DDS.
12. **`fg.yazi`**: Integrated FZF and Ripgrep file searching.

---

## 4. Keymap Architecture (Zero-Conflict Ergonomics)

### Layer 1: Core Selection & Visual Workflow (Atomic Space Ergonomics)

| Keybinding      | Action                             | Description                                                                                                            |
| :-------------- | :--------------------------------- | :--------------------------------------------------------------------------------------------------------------------- |
| `<Space>`       | `toggle` + `arrow 1`               | **Atomic Selection Toggle:** Toggle file selection and advance cursor down by 1 row (zero delay, zero which-key popup) |
| `v`             | `visual_mode`                      | **Visual Mode:** Continuous range selection while navigating cursor                                                    |
| `V`             | `visual_mode --unset`              | **Visual Unset Mode:** Continuous range deselection                                                                    |
| `<C-a>`         | `toggle_all --state=on`            | **Select All:** Select every entry in current working directory                                                        |
| `<C-r>`         | `toggle_all`                       | **Invert Selection:** Invert selection states across the directory                                                     |
| `<Esc>`         | `escape --all`                     | **Clear Selection:** Instantly clear all active selections and cancel search                                           |
| `d`             | `remove`                           | **Trash:** Move files to trash with confirmation                                                                       |
| `D`             | `remove --permanently`             | **Permanently Delete:** Delete files without trashing                                                                  |
| `p`             | `plugin smart-paste`               | **Smart Paste:** Paste into hovered directory without entering, or into CWD if hovering a file                         |
| `P`             | `paste --force`                    | **Force Paste:** Overwrite existing files during paste                                                                 |
| `f` / `F`       | `filter --smart`                   | **Live Narrowing Filter:** Dynamically filters directory (only matching files remain on screen)                        |
| `/` / `?`       | `find --smart` / `find --previous` | **Find by Name:** Vim-style cursor jump across matching filenames                                                      |
| `s`             | `plugin frank 'name all'`          | **FD Search:** Fast filename & directory search with live Bat/Eza preview                                              |
| `S`             | `plugin frank 'content rg'`        | **Ripgrep Search:** Fast full-text search with Bat preview and line highlight                                          |
| `l` / `<Enter>` | `plugin smart-enter`               | **Smart Enter:** Enter directory or open file in Neovim                                                                |
| `h`             | `leave`                            | **Leave:** Navigate to parent directory                                                                                |
| `H` / `L`       | `back` / `forward`                 | Navigate back / forward in directory history                                                                           |
| `G`             | `arrow 99999999`                   | Move cursor to bottom (Vim EOF)                                                                                        |
| `.`             | `hidden toggle`                    | **Toggle Hidden Files:** Instant atomic toggle for dotfiles (`.git`, `.config`, etc.)                                  |

---

### Layer 2: Rapid Dispatch Matrix (Leader: `,` or `\`)

_Isolated modal developer dispatcher. Dedicated prefix keys eliminate any latency on `<Space>` and
instantly trigger Which-Key candidate discovery._

| Keybinding          | Action                           | Description                                                                 |
| :------------------ | :------------------------------- | :-------------------------------------------------------------------------- |
| `, f` / `\ f`       | `plugin frank 'name all'`        | **FD File Search:** Fuzzy find file and dirs with Bat preview               |
| `, s` / `\ s`       | `plugin frank 'content rg'`      | **Ripgrep Search:** Live full-text search with Bat preview & line highlight |
| `, d` / `\ d`       | `plugin diff`                    | **Diff Files:** Interactive comparison of selected vs hovered files         |
| `, ,` / `\ \` / `T` | `plugin toggle-pane max-preview` | **Maximize Preview:** Fullscreen preview pane toggle                        |
| `, S` / `\ S`       | `plugin what-size`               | **Calculate Size:** Recursive disk usage analysis for selection or CWD      |
| `, t` / `\ t`       | `tmux new-session -A -s x_term`  | **Terminal Drop-in:** Jump directly into active Tmux session                |
| `, g` / `\ g`       | `lazygit`                        | **Lazygit Popup:** Full interactive Git TUI                                 |
| `, b` / `\ b`       | `plugin bookmarks jump`          | **Jump Bookmark:** Interactive bookmark switcher                            |
| `, m` / `\ m`       | `plugin bookmarks save`          | **Save Bookmark:** Save current directory to bookmarks                      |
| `, M` / `\ M`       | `plugin mount`                   | **Disks:** Launch Mount/Unmount/Eject Manager                               |
| `, e` / `\ e`       | `open --with edit`               | **Neovim Direct:** Edit target file in Neovim                               |
| `, z` / `\ z`       | `plugin zoxide`                  | **Zoxide Teleport:** Frequency/recency directory jump                       |

---

### Layer 3: Mnemonic Navigation (`g` - Go)

| Keybinding | Action            | Description                                         |
| :--------- | :---------------- | :-------------------------------------------------- |
| `g r`      | `plugin git-root` | **Git Root:** Jump to root of active Git repository |
| `g h`      | `cd ~`            | **Home:** Jump to `~`                               |
| `g w`      | `cd ~/Workspace`  | **Workspace:** Jump to active workspace             |
| `g c`      | `cd ~/.config`    | **Config:** Jump to `~/.config`                     |
| `g d`      | `cd ~/Downloads`  | **Downloads:** Jump to `~/Downloads`                |
| `g p`      | `cd ~/Projects`   | **Projects:** Jump to `~/Projects`                  |
| `g t`      | `cd /tmp`         | **Temporary:** Jump to `/tmp`                       |

---

### Layer 4: Clipboard & Developer Utilities (`c` - Copy / Chmod / Size)

| Keybinding | Action                            | Description                                                |
| :--------- | :-------------------------------- | :--------------------------------------------------------- |
| `c a`      | `copy path`                       | Copy **absolute path** to system clipboard                 |
| `c d`      | `copy dirname`                    | Copy **parent directory path** to clipboard                |
| `c n`      | `copy filename`                   | Copy **filename** to clipboard                             |
| `c r`      | `python3 relative path \| pbcopy` | Copy **relative path** to clipboard                        |
| `c y`      | `cat "$1" \| pbcopy`              | **Yank Content:** Copy file contents directly to clipboard |
| `c x`      | `chmod +x "$@"`                   | **Make Executable:** Apply execution permissions (`+x`)    |
| `c m`      | `plugin chmod`                    | Interactive TUI permissions editor                         |
| `c s`      | `plugin what-size`                | **What Size:** Calculate size of selection or CWD          |
| `c S`      | `plugin what-size -- '-c'`        | **What Size + Copy:** Calculate size and copy to clipboard |

---

### Layer 5: Utilities, Archives, Tags & Diagrams (`b`, `t`, `Z`, `C`, `M`)

| Keybinding    | Action                          | Description                                                                        |
| :------------ | :------------------------------ | :--------------------------------------------------------------------------------- |
| `'` / `b j`   | `plugin bookmarks jump`         | Jump to saved bookmark                                                             |
| `b s`         | `plugin bookmarks save`         | Save current path to bookmarks                                                     |
| `b d` / `b D` | `bookmarks delete/delete_all`   | Delete single bookmark / clear all bookmarks                                       |
| `t a` / `b a` | `plugin mactag add`             | **macOS Tag Add:** Add Finder color tag (Red, Orange, Yellow, Green, Blue, Purple) |
| `t r` / `b r` | `plugin mactag remove`          | **macOS Tag Remove:** Remove Finder color tag                                      |
| `C` / `Z c`   | `plugin ouch`                   | **Ouch Compress:** Interactive archive compression with auto-format detection      |
| `Z x`         | `ouch d -y "$1"`                | **Ouch Extract:** Fast unarchive (zip, tar, 7z, rar, zst, gz, bz2, xz)             |
| `Z 7`         | `7z a archive.7z "$@"`          | Fallback 7z archive creation                                                       |
| `M m`         | `plugin mermaid -- toggle-mode` | **Mermaid:** Switch preview mode (split / image / text)                            |
| `M +` / `M -` | `plugin mermaid -- zoom-in/out` | **Mermaid:** Zoom diagram in preview viewport                                      |

---

## 5. Hardware Display Calibration (macOS Liquid Retina XDR & 120Hz ProMotion)

Configured for MacBook Pro hardware profiles (14" / 16" Liquid Retina XDR, up to 3456×2234, 254 PPI,
120Hz refresh):

1. **Window Ratio (`ratio = [ 1, 2, 4 ]`):**
    - **Parent Column (14.3%):** Compact breadcrumb hierarchy.
    - **Current Column (28.6%):** High-density file list.
    - **Preview Column (57.1%):** Large viewport for syntax highlighting, LaTeX formulas, and
      Mermaid diagrams.
2. **Physical Preview Resolution (`3840 × 2400`):** Overcomes scaling artifacts on Retina displays
   and external 4K/5K monitors.
3. **Lanczos-3 Resampling (`image_filter = "lanczos3"`):** High-order sinc filter ensures
   razor-sharp diagram and image rendering without moiré.
4. **Frame Latency Sync (`image_delay = 30`, `scrolloff = 8`):** Smooth cursor kinematics
   synchronized with ProMotion displays without GPU buffer contention.
5. **Which-Key UI Layout:** Multi-column (`cols = 3`) layout with alphabetical key ordering
   (`sort_by = "key"`), cyan active candidate keys, and transparent backgrounds.

---

## 6. System Dependencies

Binaries installed via Homebrew:

```bash
brew install yazi \
             fzf \
             ripgrep \
             fd \
             bat \
             glow \
             jq \
             p7zip \
             zoxide \
             lazygit \
             neovim \
             tmux
```

_Terminal Graphics:_ Recommended terminal emulators with native Kitty Graphics Protocol (`Kgp`)
support include **Ghostty** and **Kitty**, or WezTerm with TrueColor support.

---

## 7. Package Management & Verification

### Verify Environment

```bash
ya env
```

### Upgrade Plugins

```bash
ya pkg upgrade
```

### Clean Thumbnails & Preview Cache

```bash
ya cache clean
```

---

<p align="center">
  <b>X WORKSPACE // REFERENCE YAZI SPECIFICATION</b><br>
  <i>Engineered for zero cognitive friction and maximum developer throughput.</i>
</p>
