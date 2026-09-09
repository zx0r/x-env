# ⌨️ Personal Karabiner-Elements Configuration for RK H81

Keymap and system shortcuts configuration profile for the **Royal Kludge H81** (75% layout) mechanical keyboard running on **macOS**. This setup is designed for high-efficiency development, native multimedia key behavior, and ergonomic UNIX/tiling window manager-style navigation.

---

## 🛠️ Technology Stack
*   **Hardware:** **Royal Kludge H81** Keyboard (Bluetooth Low Energy / USB-C connection)
*   **Software:** [Karabiner-Elements](https://karabiner-elements.pqrs.org/) (macOS Virtual HID Driver)
*   **Terminal Emulator:** [Kitty Terminal](https://sw.kovidgoyal.net/kitty/)
*   **Operating System:** macOS (Apple Silicon)

---

## 🚀 Key Features & Keybindings

### 1. Function Row (Top F-Row) — Tap-to-Media (No Fn Key Needed)
To match Apple's native layout, pressing F-keys directly sends native macOS media controls:

| Key | Action (Direct Press) | Description |
| :--- | :--- | :--- |
| **F1** | Decrease Screen Brightness | Native macOS action |
| **F2** | Increase Screen Brightness | Native macOS action |
| **F3** | Mission Control | Desktop overview and workspaces |
| **F4** | Launchpad | Applications dashboard grid |
| **F5** | Decrease Keyboard Backlight | Royal Kludge hardware control |
| **F6** | Increase Keyboard Backlight | Royal Kludge hardware control |
| **F7 / F8 / F9** | Media Controls (Prev / Play-Pause / Next) | Native media player control |
| **F10 / F11 / F12** | Audio Controls (Mute / Volume - / Volume +) | Native system audio control |

### 2. Fn combinations (Native Key Mappings)
Hold the **Fn** key down and press F1–F12 to trigger system tools or standard function key behavior:

| Combination | Action | Shell Command / Key Code |
| :--- | :--- | :--- |
| **Fn + F1** | Open **Finder** | `open ~` (User home directory) |
| **Fn + F2** | Open **Safari** | `open -b com.apple.Safari` (Bundle ID) |
| **Fn + F3** | Open **Mail** | `open -b com.apple.mail` |
| **Fn + F4** | Open **Calculator** | `open -b com.apple.calculator` |
| **Fn + F5 ... F12** | Standard **F5 ... F12** keys | Used for IDE debugging (VS Code, GoLand, etc.) |

### 3. Rapid Terminal Launch (UNIX-style)
*   **`Cmd + Enter`** (which corresponds to physical keys **`Alt` (next to spacebar) + `Enter`** in Mac Mode) — launches or focuses **Kitty Terminal** (`open -b net.kovidgoyal.kitty`).

### 4. Modifiers & Language Switching
*   **Language Switcher:** A single quick tap on **`Right Shift`** (or **`Right Control`**) toggles the input language (sends `Ctrl + Space`). Holding the keys behaves as standard Shift/Ctrl modifiers.
*   **Command ↔ Option:** Keys are physically in the correct macOS order due to the keyboard's hardware Mac mode (no Karabiner simple modifications software swaps are active to avoid double-swap issues):
    *   Physical **`Alt`** (adjacent to Spacebar) maps to **Command** (`Cmd + C`, `Cmd + V`, etc.).
    *   Physical **`Win`** (adjacent to left Control) maps to **Option**.

### 5. Hyper Key on Caps Lock (Advanced Shortcuts)
Holding **Caps Lock** acts as the **Hyper Key** (`Cmd + Opt + Ctrl + Shift`), while a single quick tap acts as **Escape** (perfect for Vim/Neovim):

*   **`Caps Lock (Hold) + H/J/K/L`** $\rightarrow$ Arrow Keys: Left / Down / Up / Right (Vim navigation).
*   **`Caps Lock (Hold) + U / D`** $\rightarrow$ Page Up / Page Down.
*   **`Caps Lock (Hold) + I / O`** $\rightarrow$ Home / End.
*   **`Cmd + Q (Hold)`** $\rightarrow$ Safe Application Quit (requires holding for 1 second to prevent accidental quitting).

---

## ⚙️ Detailed Configuration Steps

### Step 1: Switch Keyboard to Hardware Mac Mode
Configure your Royal Kludge H81 to use the Mac-compatible firmware layout:
1. Press and hold **`Fn + S`** for 3 seconds.
2. The keyboard backlight will flash to confirm it has successfully switched to Mac mode.
*(You can switch back to Windows mode at any time using `Fn + A`).*

### Step 2: macOS Keyboard Settings Configuration
Ensure macOS does not override standard media behaviors:
1. Go to **System Settings** $\rightarrow$ **Keyboard** $\rightarrow$ **Keyboard Shortcuts**.
2. Select **Function Keys** from the left pane.
3. Make sure that **"Use F1, F2, etc. keys as standard function keys"** is **DISABLED** (turned off).

### Step 3: Set Application Workspace Affinities
To strictly isolate applications in separate desktop workspaces:
1. Open **Mission Control** (press **F3**) and create at least 3 workspaces (Desktop 1, 2, 3) by clicking the `+` in the top right.
2. Go to **Desktop 1**, launch **Kitty**. Right-click the Kitty icon in the Dock $\rightarrow$ **Options** $\rightarrow$ under *Assign To*, select **This Desktop (Desktop on Space 1)**.
3. Go to **Desktop 2**, launch **Safari**. Right-click the Safari icon in the Dock $\rightarrow$ **Options** $\rightarrow$ under *Assign To*, select **This Desktop (Desktop on Space 2)**.
4. Go to **Desktop 3**, launch your preferred **IDE**. Right-click its icon in the Dock $\rightarrow$ **Options** $\rightarrow$ under *Assign To*, select **This Desktop (Desktop on Space 3)**.

---

## 📂 Configuration Files Structure
The Karabiner-Elements configuration is stored as a JSON file:
*   File path: `~/.config/karabiner/karabiner.json`

Karabiner dynamically reloads the configuration when changes are written to the file. Before saving edits, you can validate the syntax using:
```bash
python3 -m json.tool ~/.config/karabiner/karabiner.json > /dev/null
```
