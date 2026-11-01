# ---
# schema: "mdd-node-v1"
# id: "functions/fish_should_add_to_history.fish"
# title: "Native History Ingestion Governor & Deduplication Architecture"
# layer: "Functions / History"
# responsibility: "Pre-ingestion filter preventing transient noise, space-prefixed commands, and secret tokens from disk persistence; documents Fish 4.x native vacuum deduplication engine"
# dependencies: []
# backlinks: ["conf.d/init.fish"]
# created_at: "2026-10-18"
# updated_at: "2026-10-18"
# last_commit: "pending"
# tags: ["history", "security", "deduplication", "privacy", "zero-fork-sla", "fish-4x", "principal"]
# ---

# ==============================================================================
# FISH 4.0 HISTORY ARCHITECTURE & DEDUPLICATION SPECIFICATION
# ==============================================================================
#
# 1. ATOMIC PRE-INGESTION INTERCEPTION (Issue #10302):
#    Fish 4.x executes `fish_should_add_to_history` in-process BEFORE serializing
#    command strings to $XDG_DATA_HOME/fish/fish_history.
#    - Return 0: The command is persisted to disk and appended to active history.
#    - Return 1: The command is discarded from persistent storage, but preserved
#      in an ephemeral 1-cycle buffer (allowing immediate Up-Arrow typo recovery).
#
# 2. DEDUPLICATION ENGINE (src/history/history.rs):
#    Fish implements a dual-layer hardware-native deduplication architecture:
#    - Interactive UI Dedup (Runtime):
#      `HistorySearch` uses a resident `deduper: HashSet<WString>` to guarantee
#      O(1) on-the-fly deduplication during Up-Arrow / Ctrl+R queries. Duplicate
#      historical invocations are never presented in interactive navigation.
#    - Physical Storage Vacuum (On-Disk):
#      To minimize disk I/O, commands are appended incrementally. Every ~25 commands
#      (`countdown_to_vacuum`), an internal background maintenance task triggers:
#      1) Reads the entire `fish_history` file into memory.
#      2) Deduplicates records via LRU table compaction (`compact_new_items`).
#      3) Caps storage to HISTORY_SAVE_MAX (262,144 strictly unique entries).
#      4) Atomically commits the deduplicated corpus via POSIX `rename()`.
#    Consequently, manual external deduplication scripts (awk, Python) are
#    architecturally redundant and prone to atomic lock contention.
#
# 3. LEADING-SPACE PRIVACY CONTRACT:
#    Declaring `fish_should_add_to_history` disables Fish's default space-prefix
#    bypass. This function explicitly enforces Phase 1 to preserve leading-space
#    ephemeral privacy across all execution contexts.
# ==============================================================================

function fish_should_add_to_history --argument-names cmd --description "Determine whether command line should be persisted to disk"
    # ━━━ Phase 1: Leading-Space Ephemeral Privacy ━━━━━━━━━━━━━━━━━
    # Commands prefixed with leading whitespace denote transient intent
    if string match -qr '^\s' -- "$cmd"
        return 1
    end

    # ━━━ Phase 2: Trivial Noise & Single-Token Short Circuits ━━━━━
    # Sanitize and extract stripped command line representation
    set -l clean (string trim -- "$cmd")
    test -n "$clean"; or return 1

    switch "$clean"
        # Terminal viewport controls & session terminators
        case 'c' 'clear' 'exit' 'pwd'
            return 1
        # Bare directory inspections without scoped targets
        case 'l' 'll' 'ls' 'la' 'l.' 'lt' 't' 't2' 't3' 't4'
            return 1
        # History inspection invocations
        case 'history' 'history *'
            return 1
    end

    # ━━━ Phase 3: Zero-Ambient-Leakage Credential Scanner ━━━━━━━━━━
    # Block inline assignments of secrets, private keys, and API tokens
    if string match -qi -r '.*(api[_-]?key|bearer|token|secret|password|private_key).*=.*' -- "$clean"
        return 1
    end

    # Block raw environment exports of well-known sensitive variable keys
    if string match -qi -r '^set\s+(-[gxlu]+\s+)*(ANTHROPIC_API_KEY|OPENAI_API_KEY|GEMINI_API_KEY|GITHUB_TOKEN|AWS_SECRET_ACCESS_KEY)' -- "$clean"
        return 1
    end

    # ━━━ Phase 4: Path-Aware Security Enclave Exclusion ━━━━━━━━━━━
    # Suppress recording commands executed inside RAM-disks or SOPS directories
    set -l cwd (command -s pwd-P >/dev/null; and pwd -P; or $PWD)
    if string match -qr '(/Volumes/RamDisk|/\.secrets)' -- "$cwd"
        return 1
    end

    # Command passes all safety invariants; permit disk persistence
    return 0
end
