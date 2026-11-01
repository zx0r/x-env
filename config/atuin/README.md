## 1. Architectural Role & System Boundaries

- **Core Responsibility:** High-throughput shell command ingestion, deduplication, secret scrubbing,
  and sub-millisecond interactive recall (`Ctrl+R` and `Up-Arrow`).
- **Non-Interference Contract:**
    - **Zero Shell Wrapping:** Atuin is bootstrapped purely via native hooks. Never intercept or
      wrap `atuin` through Fish functions, subshells, or IPC hooks.
    - **Inline Native TUI:** Rendered strictly inline within the active terminal buffer
      (`tmux.enabled = false`). Floating tmux popups are prohibited to eliminate windowing focus
      penalties and preserve terminal transparency.
    - **Zero Cold-Start I/O:** Network update checks (`update_check = false`) and non-essential disk
      sync are decoupled from interactive shell startup.

---

## 2. Hard Performance SLAs & Invariants

- **Daemon Architecture (`[daemon]`):** A persistent local background worker (`atuin-daemon`)
  manages pooled SQLite write connections through a dedicated Unix domain socket
  (`$TMPDIR/atuin.sock`).
- **In-Memory Fuzzy Indexing (`daemon-fuzzy`):** Command strings are interned and indexed directly
  in the daemon process RAM, completely bypassing SQLite disk access during real-time typing.

---

## 3. Semantic Design System Contract (`theme = "x"`)

The TUI color palette is bound 1:1 to the canonical **Environment X** palette
([master.lua](file:///Users/x0r/.config/nvim/zx0r/lua/theme/master.lua) and
[kitty/themes/x.conf](file:///Users/x0r/.config/kitty/themes/x.conf)). Raw white glare and
uncalibrated ANSI colors are strictly barred.

### Active Token Map ([themes/x.toml](file:///Users/x0r/.config/atuin/themes/x.toml))

| Atuin Semantic Meaning | Hex Code  | Environment X Token      | Visual & Architectural Role                                               |
| :--------------------- | :-------- | :----------------------- | :------------------------------------------------------------------------ |
| **`Base`**             | `#7B8496` | `surface_4` (Calm Slate) | Unquoted command arguments, prose body (calm 50% luminance)               |
| **`SyntaxCommand`**    | `#00FF00` | `green / ok`             | Executable verbs (`git`, `cargo`, `docker`); matches `fish_color_command` |
| **`Guidance`**         | `#00FFFF` | `cyan / accent`          | Active selection pointer (`>`); matches `CursorLineNr`                    |
| **`Annotation`**       | `#A855F7` | `purple / type`          | Command execution duration (`123ms`, `2s`)                                |
| **`Title`**            | `#97A0BC` | `text_2` (Slate)         | Relative timestamp (`5m ago`); calm secondary scanning path               |
| **`Muted`**            | `#4A5168` | `text_4` (Graphite)      | Box borders, horizontal dividers, preview frame (zero glare)              |
| **`Important`**        | `#CD00F7` | `magenta / kw`           | Fuzzy query character match highlights                                    |
| **`AlertError`**       | `#A855F7` | `purple / type`          | Non-zero exit code badges (eliminates alarming red flashing)              |
| **`SyntaxString`**     | `#00FF00` | `green / ok`             | Quoted string literals (`"path"`, `'msg'`)                                |
| **`SyntaxOperator`**   | `#F40091` | `pink / fn`              | Pipes, redirects, conditionals (`\|`, `>`, `&&`, `\|\|`)                  |
| **`SyntaxFlag`**       | `#646B84` | `text_3` (Dim Slate)     | CLI options and flags (`--verbose`, `-rf`)                                |
| **`SyntaxVariable`**   | `#A855F7` | `purple / type`          | Environment variables (`$HOME`, `${VAR}`)                                 |

---

## 4. Architectural Traps & Anti-Patterns (Guardrails)

> [!CAUTION] **Trap 1: Never remove the `[theme]` table from
> [themes/x.toml](file:///Users/x0r/.config/atuin/themes/x.toml).**  
> Atuin’s Rust deserializer (`serde`) strictly expects a root `ThemeDefinition` struct containing
> both `[theme]` and `[colors]`. If `[theme]` is omitted, Atuin will silently discard the theme file
> and revert to the built-in `default` theme, restoring blinding white borders (`#FFFFFF`) and muddy
> gray text.

> [!WARNING] **Trap 2: Never use integer hex literals (`0xRRGGBB`) in Atuin TOML.**  
> Unlike Neovim’s C-core (`kObjectTypeInteger`), Atuin’s TOML deserializer strictly expects string
> types (`"#RRGGBB"`). Integer literals will trigger a hard deserialization panic.

> [!IMPORTANT] **Trap 3: Never enable Tmux Popups (`[tmux] enabled = true`).**  
> Native tmux popups create a detached child surface that introduces focus latency, breaks sub-shell
> transparency, and corrupts window borders. Atuin must remain inline.

---

## 5. Security & Privacy Topology

### Regex Scrubbing (`history_filter`)

Commands matching credential-sensitive or transient patterns are dropped before reaching SQLite:

```toml
history_filter = [
  "^export.*(KEY|SECRET|PASSWORD|TOKEN|AUTH|CREDENTIAL|PASS|SIGNING)",
  "^set -[gU]?x?.*(KEY|SECRET|PASSWORD|TOKEN|AUTH)",
  "^aws configure",
  "^ssh-add",
  "^ssh-keygen",
  "^gpg ",
  "^security find-generic-password",
  "^sops",
  "^age",
  "^get-secret",
  ".*(-p|--password|--token|--secret|--api-key)[ =].+",
  ".*Authorization: Bearer .+"
]
```

### Automatic Scanner

- `secrets_filter = true`: Built-in automated entropy and signature scanner for AWS keys, GitHub
  PATs, Slack webhooks, and Stripe secrets.
- `cwd_filter = ["^/private", "^/tmp/secrets"]`: Automatic directory blackout.

---

## 6. Directory Map & Diagnostics

```
~/.config/atuin/
├── config.toml               # Master engine configuration
├── themes/
│   └── x.toml                # Environment X semantic theme definition
└── README.md                 # Architectural specification (this file)
```

### Operational Verification

```fish
# Check daemon health & SQLite connection
atuin status

# Full client diagnostics
atuin doctor
```
