# ---
# schema: "mdd-node-v1"
# id: ".meta/research_startup_latency.md"
# title: "Systems Engineering Report: Shell Startup Latency Optimization"
# layer: "Meta / Logging"
# responsibility: "Provides comprehensive diagnostic data, trace analysis, and optimization benchmarks for zero-fork cold boot sequence"
# dependencies: []
# backlinks: ["MAP_OF_CONTENT.md"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["research", "performance", "latency", "benchmark", "telemetry"]
# ---

# Systems Engineering Report: Shell Startup Latency Invalidation and Optimization

## I. Executive Summary
This report documents the diagnostic methodologies, latency tracing, and architectural optimization passes executed on the user's Fish shell environment on macOS (Apple Silicon Architecture). By identifying and eliminating synchronous command evaluation subprocesses (process forks) during the terminal initialization path, cold boot latency was reduced from **~32.08 ms** to a highly optimized **21.0 ms ± 1.7 ms** (minimum recorded: **19.7 ms**), approaching the theoretical bare-metal shell execution baseline of **~9.5 ms**.

---

## II. Baseline Configuration & Diagnostic Methodology
To profile the execution timeline and identify specific bottlenecks, the following commands were executed under a standardized, warm CPU state:

```bash
# Hyperfine cold launch performance test
hyperfine --warmup 10 --runs 50 "fish -i -c exit"

# Bare-metal shell baseline (no user configuration)
hyperfine --warmup 10 --runs 50 "fish --no-config -i -c exit"

# Chronological execution profiling with exclusive and inclusive metrics
fish --profile-startup /tmp/config_prof.prof -ic exit
```

### 1. Bare-metal baseline metrics (No User Config)
```text
Benchmark 1: fish --no-config -i -c exit
  Time (mean ± σ):       9.5 ms ±   1.0 ms    [User: 5.7 ms, System: 2.2 ms]
  Range (min … max):     8.6 ms …  13.8 ms    50 runs
```
*Note: A fixed startup overhead of ~5.5 ms is spent internally in the Fish C++ binary during internal theme initialization (`fish_config theme choose default --no-override`).*

---

## III. Phase 1: GPG TTY Process Fork Elimination
### 1. Telemetry and Identification
Profiling traces highlighted a synchronous `/usr/bin/tty` invocation within the GPG configuration module:
```text
  Exclusive (ms) │ Inclusive (ms) │ Source File / Operation
  ────────────────┼────────────────┼────────────────────────────────────────
         6.12     │        6.12    │ set -gx GPG_TTY (tty)
```
In macOS (Darwin kernel), spawning a child process (`fork` + `execve`) incurs a system validation latency overhead ranging from 5 to 8 ms due to security catalog check operations (`amfid`).

### 2. Architectural Remediation
The synchronous boot-time execution was replaced by introducing lazy-loading command wrappers. 
*   **Action:** Removed `set -gx GPG_TTY (tty)` from `conf.d/11-ssh-gpg.fish`.
*   **Wrapper Implementation (`functions/git.fish`, `functions/gpg.fish`, etc.):**
    ```fish
    function git --description "Wrapper for git to lazily set GPG_TTY"
        if not set -q GPG_TTY
            set -gx GPG_TTY (command tty)
        end
        command git $argv
    end
    ```
By shifting the process spawn to execution time, GPG TTY alignment costs are only paid when active cryptographic commands are run, reducing shell startup latency to **26.5 ms ± 1.3 ms**.

---

## IV. Phase 2: Micromamba Auto-Completion Deferral
### 1. Telemetry and Identification
A second latency trace after GPG optimization revealed high CPU time spent inside `mamba.fish`:
```text
  Exclusive (ms) │ Inclusive (ms) │ Source File / Operation
  ────────────────┼────────────────┼────────────────────────────────────────
         221.0    │       8756.0   │ source $static_cache_directory_path/mamba.fish
         256.0    │       5910.0   │ source "$static_cache_directory_path/mamba.fish"
         118.0    │       2552.0   │ for line in (string split \n (string trim $argv[2]))...
```
While Micromamba environment hooks were statically cached to bypass dynamic execution, reading the large, compiled `mamba.fish` file (~5.9 ms) required the shell parser to synchronously register hundreds of tab-completion specifications on every terminal launch.

### 2. Architectural Remediation
We isolated the completions registry and environment variables into lazy loading modules:
1.  **Lazy Initialization Function (`functions/micromamba.fish`):**
    Sets up `MAMBA_ROOT_PREFIX` and updates `$PATH` dynamically on first call:
    ```fish
    function micromamba
        if not set -q MAMBA_SHLVL
            set -gx MAMBA_SHLVL "0"
            set -gx MAMBA_ROOT_PREFIX "$HOME/.local/share/mamba"
            set -gx MAMBA_EXE "/Users/x0r/.local/share/mise/installs/micromamba/latest/bin/micromamba"
            fish_add_path --move $MAMBA_ROOT_PREFIX/condabin
        end
        # Wrapper delegation logic...
    end
    ```
2.  **Deferred completions (`completions/micromamba.fish` & `completions/mamba.fish`):**
    Moved the entire completion payload (`complete` statements) into autoloading completions namespaces. They are now read by Fish only when tab-completion is actively triggered.

---

## V. Phase 3: Autoloading Refactoring for Utility Functions
### 1. Telemetry and Identification
A third audit focused on lexical parsing overhead during boot. In Fish, defining functions inside configuration files forces the interpreter to parse and compile their syntax blocks sequentially during startup, even if the functions are never called. 

The file `conf.d/25-fs-utils.fish` declared over 20 filesystem and fuzzy search utilities (such as `up`, `mkcd`, `Rg`, `TODOS`, `gitf`, etc.), representing ~250 lines of code. Traces indicated this file read took **~1.6 - 2.2 ms** on boot. Additionally, `fzf_preview`, `refresh_shell_cache`, and `mise-bootstrap` were also defined in `conf.d/` initializers.

### 2. Architectural Remediation
Following Fish best practices, we completely decoupled function definitions from startup Initializers.
*   **Action:** Deleted `conf.d/25-fs-utils.fish` entirely.
*   **Autoloading Migration:** Moved all 23 functions to their own files inside `functions/` (e.g., `functions/up.fish`, `functions/fzf_preview.fish`, etc.).
Now, the shell starts up without parsing any of these utility functions. They are compiled and loaded on-demand only when executed.

---

## VI. Validation & Target Verification
Following Phase 3, a clean cache reload was run (`refresh_shell_cache`):
```text
==========================================================================
 ⚡ Fish Shell Startup Latency Profiler & Benchmark Suite
==========================================================================

[4/4] Execution Performance Benchmark (Cold Launch)
  Executing hyperfine benchmark (10 warmup, 50 runs)...

Benchmark 1: fish -i -c exit
  Time (mean ± σ):      20.1 ms ±   1.0 ms    [User: 13.1 ms, System: 5.6 ms]
  Range (min … max):    19.0 ms …  22.9 ms    50 runs
```

### Empirical Comparison
| Benchmark State | Startup Latency | Overhead to Bare Fish |
| :--- | :--- | :--- |
| **Bare-metal Fish (`--no-config`)** | 9.5 ms ± 1.0 ms | 0.0 ms |
| **Legacy configuration (Atuin subprocesses)** | ~64.5 ms | ~55.0 ms |
| **Initial Optimization (Mise Decoupled, Cache Normalized)** | 32.08 ms | 22.58 ms |
| **GPG_TTY & Lazy Mamba Optimization (Phase 1-2)** | 21.0 ms ± 1.7 ms | 11.5 ms |
| **Fully Autoloaded Helper Functions (Phase 3)** | **20.1 ms ± 1.0 ms** | **10.6 ms** |
