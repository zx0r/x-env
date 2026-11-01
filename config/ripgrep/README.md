# ripgrep Configuration & Architecture Specification

Specification and operational guide for the global [ripgrep](https://github.com/BurntSushi/ripgrep) deployment.

- **Config Path**: `~/.config/ripgrep/ripgreprc`
- **Ignore Path**: `~/.config/ripgrep/ripgrep_ignore`
- **Environment Variable**: `RIPGREP_CONFIG_PATH=/Users/x0r/.config/ripgrep/ripgreprc`
- **Target Platform**: macOS (Darwin arm64 / Apple Silicon)
- **Active Engine**: ripgrep 15.2.0 (`+pcre2`, `+NEON` SIMD)
- **Validation Script**: [`~/.local/bin/ripgrep/validate.sh`](file:///Users/x0r/.local/bin/ripgrep/validate.sh)

---

## 1. Architectural Principles & Performance Invariants

ripgrep does not discover configuration files automatically from arbitrary directories; it loads a single configuration file if and only if the `RIPGREP_CONFIG_PATH` environment variable is defined. The global configuration is designed according to the following architectural constraints:

1. **Aho-Corasick Compiled Ignore Engine**:
   - Defining exclusion patterns through repetitive `--glob` flags forces ripgrep's CLI lexer to parse dozens of arguments on every process execution.
   - Delegating exclusions to [`~/.config/ripgrep/ripgrep_ignore`](file:///Users/x0r/.config/ripgrep/ripgrep_ignore) via `--ignore-file` allows ripgrep to compile rules directly into its Gitignore trie matcher, minimizing cold-start overhead.
2. **Search Correctness (No Truncated Traversal)**:
   - Global `--max-depth` constraints are strictly avoided. Hardcoding depth limits causes silent omissions in nested directory hierarchies, monorepos, and submodules.
   - Depth constraints are left to explicit command-line invocations (`-d <N>`).
3. **Symlink Boundary Isolation**:
   - The `--follow` flag is prohibited in the global configuration. Following symlinks globally causes infinite loops on recursive structures and hard errors (`os error 2: No such file or directory`) on broken symlinks in cache or package directories.
   - Symlink traversal is activated on demand via `-L` / `--follow`.
4. **Dynamic Engine Selection**:
   - Modern ripgrep supports `--engine=auto`, superseding the deprecated `--auto-hybrid-regex`. This dispatches standard searches to the Rust DFA regex engine with Apple Silicon NEON vector acceleration, dynamically falling back to PCRE2 JIT only when lookaround or backreference syntax is detected.

---

## 2. Configuration Breakdown ([`ripgreprc`](file:///Users/x0r/.config/ripgrep/ripgreprc))

The configuration file follows the `rc` format where each line represents a single shell argument. Blank lines and lines prefixed with `#` are ignored.

```ini
# Search Mechanics
--smart-case
--hidden
--line-number
--engine=auto

# Output Constraints & Formatting
--max-columns=400
--max-columns-preview
--hyperlink-format=default

# Color Specifications (24-bit TrueColor)
--color=auto
--colors=path:fg:0x8B,0xE9,0xFD
--colors=path:style:bold
--colors=line:fg:0x62,0x72,0xA4
--colors=line:style:nobold
--colors=column:fg:0xBD,0x93,0xF9
--colors=column:style:bold
--colors=match:fg:0x50,0xFA,0x7B
--colors=match:style:bold

# File Type Extensions
--type-add=web:*.{html,css,scss,sass,less,js,jsx,ts,tsx,vue,svelte}*
--type-add=csv:*.{csv,tsv}
--type-add=pyi:*.pyi
--type-add=hx:*.hx
--type-add=lock:*.{lock,lockb}
--type-add=config:*.{json,yaml,yml,toml,ron,ini,env}*

# Boundary Safety
--glob=!.git/*

# Global Ignore Engine
--ignore-file=/Users/x0r/.config/ripgrep/ripgrep_ignore
```

### Directive Roles

| Directive | Purpose |
| :--- | :--- |
| `--smart-case` | Case-insensitive matching when the pattern contains only lowercase; case-sensitive when uppercase is present. |
| `--hidden` | Recursively searches hidden files and dotfiles (e.g., `.config`, `.github`, `.env.example`). |
| `--line-number` | Ensures 1-indexed line numbers are output in both interactive TTY and Unix pipe streams. |
| `--engine=auto` | Dynamically selects between the high-speed Rust regex engine and PCRE2 JIT. |
| `--max-columns=400` | Suppresses terminal line flooding from minified files, while displaying full code context for modern screen widths. |
| `--max-columns-preview` | Displays a short preview snippet of matched lines exceeding the column limit. |
| `--hyperlink-format=default` | Emits standard OSC 8 terminal hyperlinks, allowing file paths to be clicked directly in supported terminals (Kitty, iTerm2, WezTerm). |
| `--glob=!.git/*` | Explicit boundary barrier. When `--hidden` is enabled, this prevents ripgrep from traversing raw Git object databases. |

### Color Token Palette (TrueColor)

Colors are configured using 24-bit RGB values (`0xR,0xG,0xB`):

- **Path**: Cyan (`0x8B,0xE9,0xFD`, bold)
- **Line**: Slate Gray (`0x62,0x72,0xA4`, regular)
- **Column**: Lavender (`0xBD,0x93,0xF9`, bold)
- **Match**: Spring Green (`0x50,0xFA,0x7B`, bold)

---

## 3. Ignore Rules Hierarchy ([`ripgrep_ignore`](file:///Users/x0r/.config/ripgrep/ripgrep_ignore))

ripgrep applies ignore rules in the following order of precedence:

1. Command-line globs (`--glob`)
2. Local `.ignore` and `.rgignore` in search directories
3. Local `.gitignore` in repository directories
4. Global ignore file specified via `--ignore-file` ([`~/.config/ripgrep/ripgrep_ignore`](file:///Users/x0r/.config/ripgrep/ripgrep_ignore))
5. Global Git excludes (`core.excludesFile`, defaults to [`~/.config/git/ignore`](file:///Users/x0r/.config/git/ignore))

### Global Ignore Structure

[`ripgrep_ignore`](file:///Users/x0r/.config/ripgrep/ripgrep_ignore) standardizes common ignore targets across developer ecosystems:

- **VCS Internals**: `.git/`, `.git-crypt/`, `.git_template/`, `.svn/`, `.hg/`
- **Node / JS Ecosystem**: `node_modules/`, `.npm/`, `.yarn/`, `.pnpm-store/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb`
- **Python Ecosystem**: `__pycache__/`, `*.pyc`, `*.pyo`, `.venv/`, `venv/`, `.mypy_cache/`, `.pytest_cache/`, `.ruff_cache/`, `.ipynb_checkpoints/`
- **Rust Toolchain**: `target/`, `.cargo/`, `.rustup/`, `cargo/registry/`
- **Build Artifacts & Bundles**: `dist/`, `build/`, `_build/`, `out/`, `.next/`, `.nuxt/`, `.output/`, `*.min.js`, `*.min.css`, `*.bundle.js`, `*.map`
- **macOS / APFS Metadata**: `.DS_Store`, `.AppleDouble`, `.LSOverride`, `.Spotlight-V100`, `.Trashes`, `.fseventsd`, `.apdisk`
- **Editor / Workspace State**: `.idea/`, `.vscode/`, `.vs/`, `*.swp`, `*.swo`, `*~`, `*.bak`, `tags`, `TAGS`
- **Logs & Dumps**: `*.log`, `npm-debug.log*`, `yarn-debug.log*`, `.cache/`, `tmp/`, `*.stackdump`

---

## 4. Architectural Traps & Best Practices

> [!CAUTION]
> **Trap 1: Shell Variable & Tilde Expansion in `ripgreprc`**  
> ripgrep does not perform shell expansion on configuration lines. Passing `--ignore-file=~/.config/ripgrep/ripgrep_ignore` will fail with `rg: ~/.config/ripgrep/ripgrep_ignore: No such file or directory (os error 2)`.  
> *Rule*: Always provide absolute filesystem paths in `ripgreprc`.

> [!WARNING]
> **Trap 2: Glob Overload vs Ignore File**  
> Adding dozens of `--glob=!...` lines in `ripgreprc` degrades CLI flag parsing throughput.  
> *Rule*: Keep `ripgreprc` minimal; delegate file-based ignore patterns to `ripgrep_ignore`.

> [!IMPORTANT]
> **Trap 3: Deprecated Flag `--auto-hybrid-regex`**  
> In ripgrep 14 and 15, `--auto-hybrid-regex` is deprecated.  
> *Rule*: Use `--engine=auto`. It dynamically routes patterns requiring advanced regex features (lookaround, lookbehind) to PCRE2 while keeping pure Rust regex DFA speed for standard queries.

> [!NOTE]
> **Trap 4: Overriding Configuration in Shell Sessions**  
> To run an unrestricted search ignoring all rules, pass `-uuu` (searches hidden, ignores, and binary files). To bypass the global configuration file entirely for deterministic automation, use `--no-config`.

> [!CAUTION]
> **Trap 5: Forcing `--heading` in `ripgreprc` Breaks Pipelines**  
> ripgrep automatically enables `--heading` when stdout is connected to a TTY. Hardcoding `--heading` in `ripgreprc` forces heading layout even when piped into downstream utilities (`rg pattern | fzf`, `awk`, `sed`), breaking one-match-per-line expectations.  
> *Rule*: Never specify `--heading` in `ripgreprc`. Let ripgrep's native TTY auto-detection govern heading presentation.

---

## 5. Verification & Conformance Script

A standalone validation script is maintained at [`~/.local/bin/ripgrep/validate.sh`](file:///Users/x0r/.local/bin/ripgrep/validate.sh).

### Invariants Tested

1. **Binary & Platform**: Resolves executable, checks Apple Silicon NEON vector acceleration and PCRE2 JIT compilation.
2. **Configuration Integrity**: Confirms `ripgreprc` and `ripgrep_ignore` existence, syntax validity, and directive compatibility.
3. **Type Definitions**: Verifies registration of custom types (`web`, `csv`, `pyi`, `hx`, `lock`, `config`).
4. **Functional Search Execution**:
   - Case-insensitive literal matching.
   - PCRE2 zero-width lookaround regex matching (`(?<=...)`).
   - Boundary isolation: confirms `.git` and `node_modules` are ignored while hidden configuration files are indexed.
5. **Cold-Start Performance Benchmark**: Asserts cold invocation latency is $\le 50\text{ ms}$.

### Execution

```bash
# Run validation (defaults to zero flags, exit code 0 on success)
~/.local/bin/ripgrep/validate.sh

# JSON output mode
~/.local/bin/ripgrep/validate.sh --json
```

---

## 6. Directory Layout

```
~/.config/ripgrep/
├── README.md               # Architectural specification (this file)
├── ripgrep_ignore          # Global ignore rules (compiled Gitignore trie format)
└── ripgreprc               # Master ripgrep flag configuration

~/.local/bin/ripgrep/
└── validate.sh             # Conformance and benchmark test script
```
