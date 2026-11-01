# AGENTS.md

# Principal AI & System Engineering Autonomous Agent Directive

# High-Density System Architecture, Multi-Language Syntax Engine & Display Ergonomics

# Target: macOS Apple Silicon (ARM64) | bat 0.26.1 | tmux 3.7c | Fish Shell

## 1. Executive Mandate & Architectural Identity

This repository (`~/.config/bat`) governs the core text inspection, syntax highlighting, and paging
runtime for a Lead Scientist Developer Workstation. Every autonomous AI agent operating within or
interfacing with this codebase must embody the role of **Principal System Engineer & Principal
Architect**.

### Core Directives

1. **Zero Overhead Execution Contract:** Paging and code inspection are interactive terminal
   hotpaths. Any configuration change, wrapper script, or grammar addition that degrades the native
   cold execution floor ($t \le 10\text{ ms}$ on Apple Silicon) is strictly prohibited.
2. **Immutable Read-Only Safety:** Diagnostic, benchmarking, and auditing tasks must **never**
   mutate existing production files (`bat.conf`, `themes/x.tmTheme`, `syntaxes/`) without explicit,
   verified architectural mandates.
3. **Formal Verification:** All proposed changes must be scientifically substantiated by empirical
   benchmarks (`hyperfine`), algorithmic complexity proofs ($O(1)$ vs $O(N)$), and perceptual
   colorimetry mathematics (W3C APCA / OKLCH).

---

## 2. Subject Matter Domains

```
                                  KNOWLEDGE TAXONOMY

  ┌─────────────────────────────────┐       ┌─────────────────────────────────┐
  │  DOMAIN 1: SYSTEMS ARCHITECTURE │       │   DOMAIN 2: SYNTAX ENGINEERING  │
  │  • Rust syntect runtime         │       │  • Sublime YAML PDA grammars    │
  │  • Bincode 2-tier serialization │       │  • Extension resolution matrix  │
  │  • GlobBuilder compiler stalls  │       │  • Polyglot Markdown embedding  │
  │  • Mach task / dyld4 floor      │       │  • CUDA/Typst/Julia/Zig stubs   │
  └────────────────┬────────────────┘       └────────────────┬────────────────┘
                   │                                         │
                   └────────────────────┬────────────────────┘
                                        │
  ┌─────────────────────────────────────┴─────────────────────────────────────┐
  │                                                                           │
  ┌────────────────▼────────────────┐       ┌────────────────▼────────────────┐
  │  DOMAIN 3: TERMINAL & MULTIPLEX │       │  DOMAIN 4: DISPLAY COLORIMETRY  │
  │  • tmux 3.7c TrueColor passthru │       │  • W3C APCA SAPC-8 v0.98G-4g    │
  │  • less flags (-R, -F, -K, -mouse)│     │  • OKLCH polar perceptual space │
  │  • Alternate screen smcup/rmcup │       │  • Chromostereopsis mitigation  │
  │  • Env precedence ($BAT_PAGER)  │       │  • Guided Search 6.0 salience   │
  └─────────────────────────────────┘       └─────────────────────────────────┘
```

---

### Domain 1: Systems Architecture & Runtime Performance

#### 1.1 The Syntect / Bincode Two-Tier Automaton

`bat` relies on `trishume/syntect` to parse Sublime Text `.sublime-syntax` YAML grammars into
pushdown automata.

- **Top-Level Metadata (`SyntaxReference`):** Serialized via `bincode` without compression
  (`COMPRESS_SYNTAXES = false`). Stores lightweight routing primitives: `name`,
  `file_extensions: Vec<String>`, `scope: Scope`, and `first_line_match`. Deserialization across
  250+ languages takes $\le 3.5\text{ ms}$.
- **Lazy Context Payloads (`LazyContexts`):** Heavy Oniguruma regex DFA state tables are
  individually zlib-compressed (`serialized_lazy_contexts: Vec<u8>`). They are evaluated on-demand
  via `std::sync::OnceLock::get_or_init(...)`. Only the active language grammar is decompressed at
  runtime.
- **Binary Asset Cache:** Assets reside in `~/.cache/bat/syntaxes.bin` (~1.07 MB) and `themes.bin`
  (~407 KB), compiled once via `bat cache --build`.

#### 1.2 The Runtime `--map-syntax` Glob Compilation Bottleneck

- **Mechanics:** Each `--map-syntax` line in `bat.conf` calls
  `globset::GlobBuilder::new().compile_matcher()`. This translates the glob into an anchored regex
  and compiles an independent NFA/DFA transition table via the Rust `regex` engine on the main
  thread.
- **Empirical Penalty:** Ingesting 60–100 `--map-syntax` lines inflates startup time from **10.4
  ms** to **22.7 ms** (+117%), doubles memory consumption from **9.8 MiB** to **19.1 MiB**, and
  wastes **198,000,000 CPU instructions**.
- **Lookup Inefficiency:** At runtime, `bat` iterates sequentially ($O(N)$) through independent
  `GlobMatcher` instances rather than a unified `GlobSet`.

---

### Domain 2: Multi-Language Syntax Engineering & Polyglot Parsing

#### 2.1 Grammar Resolution Precedence (LIFO Hierarchy)

When resolving the grammar for an input stream, `bat` applies the following order of precedence:

1. Explicit CLI override (`-l, --language <name>`).
2. Custom runtime mappings (`--map-syntax`), evaluated LIFO (`.rev()`).
3. Binary cache extension match (`SyntaxSet::find_syntax_by_extension`).
4. First-line shebang / regex match (`SyntaxSet::find_syntax_by_first_line`).
5. Built-in system mappings (`src/syntax_mapping/builtins/*.toml`).
6. Fallback to `Plain Text`.

#### 2.2 Polyglot Parsing Boundaries & Jupyter Invariant

- **Markdown Fences:** Sublime Text YAML grammars cannot dynamically interpolate captured strings
  into scopes (e.g. `embed: scope:source.$1` is impossible). Fenced languages must be statically
  enumerated in `markdown.sublime-syntax`. Languages such as Julia, Zig, Typst, CUDA, Nix, and
  Docker fall back to unhighlighted raw text unless explicitly added to the Markdown grammar.
- **Jupyter Notebooks (`.ipynb`):** `.ipynb` files are valid JSON. Because `syntect` is a
  single-stream lexical automaton, it cannot parse JSON structures, decode escaped newlines (`\n`),
  and contextually apply Python highlighting to `"source"` arrays. Native `bat` displays notebooks
  as JSON. Preprocessing must occur upstream via CLI (e.g. `jq`).

---

### Domain 3: Terminal Multiplexer, Pagers & Shell Interaction

#### 3.1 Tmux 3.7c 24-bit TrueColor & Feature Arrays

- **Terminfo:** Inside tmux, `TERM` must be `tmux-256color` (or `screen-256color`). Outside tmux on
  macOS, `xterm-kitty` or `xterm-256color`.
- **Delimiter Rule:** In tmux 3.2+, `terminal-features` entries must be delimited by **colons
  (`:`)**, not commas. Using commas creates broken orphan array elements (`clipboard`, `hyperlinks`
  as separate invalid terminals).
    - _Correct:_ `set -as terminal-features ",*:RGB:clipboard:hyperlinks:mouse"`
    - _Incorrect:_ `set -as terminal-features ",*:RGB,clipboard,hyperlinks,mouse"`

#### 3.2 Less Flag Mechanics & Screen Buffer Integrity

- **Color Preservation:** `-R` (`--RAW-CONTROL-CHARS`) must be used instead of `-r`. Lowercase `-r`
  treats escape sequences as raw bytes without tracking column positions, causing wrapped lines and
  cursor position corruption.
- **Alternate Buffer Preservation:** Never use `-X` (`--no-init`). `bat` handles small files via
  `--paging=auto` in the primary buffer. Long files must open `less` in the alternate buffer
  (`smcup`/`rmcup`) so that exiting via `q` restores the prompt cleanly.
- **Environment Variable Isolation Invariant:**
  $$\text{CLI } (--pager) > \$BAT\_PAGER > bat.conf\ (--pager) > \$PAGER$$ **Mandatory Rule:**
  Neither `$BAT_PAGER` nor `$BAT_THEME` must EVER be exported in shell startup files (`config.fish`,
  `.zshrc`, `.bashrc`). Exporting `$BAT_PAGER` (e.g. legacy `less -rf`) silently shadows `bat.conf`,
  corrupts column math with lowercase `-r`, and breaks single-source-of-truth. `bat.conf` is the
  sole authoritative runtime specification.

---

### Domain 4: Display Colorimetry & Cognitive Ergonomics

#### 4.1 APCA SAPC-8 v0.98G-4g vs Legacy WCAG 2.x

- **WCAG 2.1 Failure:** WCAG 2.x relative luminance ($R = (L_1 + 0.05)/(L_2 + 0.05)$) assumes
  contrast symmetry. On dark backgrounds, low-luminance colors (e.g. `#7B8496` on `#101216`) pass
  WCAG ($4.98:1$), but fail APCA at $L_c \approx -35.9$, causing severe eye strain.
- **APCA Target Contrast Tiers (Dark Substrate `#101216`):**
    - **Tier 1 (Body Text):** $|L_c| \in [75, 85]$ (fluent reading).
    - **Tier 2 (Secondary / Entities):** $|L_c| \in [60, 70]$ (high-density recognition).
    - **Tier 3 (Comments / Inline Docs):** $|L_c| \in [45, 55]$ (peripheral reading).
    - **Tier 4 (Gutters / Structure):** $|L_c| \in [30, 38]$ (spatial alignment without visual
      noise).

#### 4.2 OKLCH Perceptual Geometry & Chromostereopsis

- **Luminance Hijacking (Guided Search 6.0):** The magnocellular pathway processes luminance
  contrast in ~30–50ms; chromatic hue processing takes ~80–120ms. If number literals sit at
  $L_c =
  -90.3$ while types sit at $L_c = -26.8$, bottom-up salience hijacks the engineer's visual
  search. Syntax tokens must be constrained to a narrow isoluminance band ($L \in [0.78, 0.85]$).
- **Chromostereopsis Mitigation:** Juxtaposing pure red ($\lambda \approx 650\text{ nm}$) with pure
  cyan ($\lambda \approx 480\text{ nm}$) induces up to $2.0\text{ D}$ of ciliary accommodation
  stress. Chroma must be clamped at $C \le 0.130$.

---

## 3. Best Practices Matrix

| Category         | Best Practice Directive                                                  | Architectural Rationale                                                                                     |
| :--------------- | :----------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------- |
| **Performance**  | Declare file associations in `.sublime-syntax` headers                   | Shuts down $O(N)$ `GlobBuilder` compilation; shifts resolution to $O(1)$ string matching in `syntaxes.bin`. |
| **Performance**  | Use `--no-config` for machine-invoked scripts (`fzf`, `git`)             | Bypasses `fs::canonicalize`, `same_file`, and `shell_words` parsing, hitting native sub-10ms floor.         |
| **Syntax**       | Add explicit fallback for CUDA (`*.cu:C++`, `*.cuh:C++`)                 | Upstream syntect lacks CUDA; fallback prevents plain-text monochromatic regression.                         |
| **Syntax**       | Preserve `--map-syntax="*.rs:Rust"` in `bat.conf`                        | Prevents local `cargo.sublime-syntax` from hijacking Rust source files under `source.build_results`.        |
| **Paging**       | Use `less -R -F -K --mouse`                                              | `-R` protects column calculations; `-F` exits one-screen files; `-K` cleanly handles `Ctrl+C`.              |
| **Paging & Env** | Strictly prohibit exporting `$BAT_PAGER` and `$BAT_THEME` in shell files | Eliminates shell pollution; preserves `bat.conf` as the immutable single source of truth.                   |
| **Terminal**     | Use colon separators in tmux `terminal-features`                         | Ensures valid capability parsing in tmux 3.2+ without orphaned array items.                                 |
| **Theming**      | Enforce OKLCH isoluminance banding ($L \approx 0.80$, $C \le 0.130$)     | Eliminates magnocellular luminance hijacking and ocular chromostereopsis fatigue.                           |
| **Theming**      | Maintain solid dark background (`#101216` / `#16181D`)                   | Prevents Mini-LED blooming and contrast degradation caused by window alpha transparency.                    |

---

## 4. Anti-Patterns Matrix

| Anti-Pattern                | Description & Manifestation                                                  | Immediate Failure Mode                                                                      | Architectural Remedy                                                            |
| :-------------------------- | :--------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------ |
| **Shell Variable Export**   | Exporting `$BAT_PAGER` (e.g. `less -rf`) or `$BAT_THEME` in shell configs.   | Silently shadows `bat.conf`, corrupts column math via lowercase `-r`, emits false warnings. | Purge exports from shell files; let `bat.conf` govern 100% of runtime settings. |
| **Glob Flooding**           | Adding dozens of standard mappings (`*.py:Python`, `*.go:Go`) to `bat.conf`. | +15ms startup latency, 198M wasted CPU cycles, 2x RAM footprint.                            | Delete standard mappings; let `bat` resolve built-in assets directly.           |
| **Slow Shell Wrapping**     | Creating fish functions that wrap `bat` with dynamic argument inspection.    | Degrades subshell performance; ignored by external callers (`git`, `fzf`).                  | Direct binary execution; use static environment exports.                        |
| **Alternate Screen Trap**   | Passing `-X` (`--no-init`) to `less`.                                        | Paged content clobbers terminal history on exit; breaks scrollback hygiene.                 | Omit `-X`; allow `bat`'s `--paging=auto` to handle buffer allocation.           |
| **Tmux Comma Delimitation** | Using `set -as terminal-features ",*:RGB,clipboard"`.                        | Corrupts tmux server feature table; creates orphan array entries.                           | Use colons: `set -as terminal-features ",*:RGB:clipboard"`.                     |
| **Rainbow Salad Theming**   | Using 12 unconstrained, hyper-saturated hex hues ($C > 0.25$).               | Cognitive overload ($> 4 \pm 1$ chunks); ocular fatigue within 30 minutes.                  | Cluster tokens into 4 semantic APCA tiers ($L_c \in [-34, -80]$).               |
| **Luminance Inversion**     | Numbers/literals brighter than types and structural keywords.                | Involuntary eye saccades towards arbitrary constants instead of logic.                      | Calibrate token lightness in OKLCH to $L \in [0.78, 0.85]$.                     |

---

## 5. Agent Verification Runbook & Health Checks

When validating the system state or verifying new configurations, autonomous agents must execute the
following non-destructive test suite:

```fish
# 1. Verify bat version and Apple Silicon target
bat --version
# Expect: bat 0.26.1 (aarch64-apple-darwin)

# 2. Verify binary cache integrity and asset sizes
ls -la ~/.cache/bat/
# Expect: syntaxes.bin (~1MB), themes.bin (~400KB), metadata.yaml

# 3. Execute multi-language syntax test suite
~/.local/bin/bat/run_tests.fish
# Expect: 33/33 PASS across all test fixtures & CLI features

# 4. Profile startup latency
hyperfine --warmup 5 --runs 30 \
  "bat --no-config tests/fixtures/sample.rs" \
  "bat tests/fixtures/sample.rs"
# Expect: delta between commands <= 15ms

# 5. Verify shell environment hygiene (zero variable shadowing)
fish -c 'echo "BAT_PAGER: <$BAT_PAGER> | BAT_THEME: <$BAT_THEME>"'
# Expect: BAT_PAGER: <> | BAT_THEME: <> (strictly empty; 100% governed by bat.conf)
```

---

## 6. Document Governance

- **Authority:** Lead Systems Architect & Principal AI Engineer (`Environment X`).
- **Review Cycle:** Triggered upon any upgrade of `bat`, `syntect`, `tmux`, or addition of local
  syntaxes.
- **Modification Protocol:** Invariants and anti-patterns defined in this document are binding
  across all automated and human interventions.
