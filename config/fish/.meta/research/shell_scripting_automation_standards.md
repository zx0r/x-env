# ---
# schema: "mdd-node-v1"
# id: ".meta/research_shell_automation_standards.md"
# title: "Architectural Research: Shell Scripting Automation & Naming Standards"
# layer: "Meta / Research"
# responsibility: "Documents state-of-the-art Bash/Fish automation patterns based on POSIX 2024 and Google Shell Style Guide to enforce robustness and idempotency."
# dependencies: []
# backlinks: ["MAP_OF_CONTENT.md", ".mise/tasks/setup-identity"]
# created_at: "2026-09-22"
# updated_at: "2026-09-22"
# tags: ["architecture", "bash", "google-style-guide", "automation", "idempotency"]
# ---

# Architectural Review: Shell Scripting Automation & Standards

**Date:** 2026-09-22
**Domain:** System Automation & Workstation Architecture

Following a rigorous analysis of the **Google Shell Style Guide**, **POSIX 2024 specifications**, and modern shell automation patterns, this document establishes the Etalon (reference) standards for all automation scripts (e.g., `mise` tasks) in the X-ENV workstation.

---

## 1. Naming Conventions & Scope Hierarchy
The Google Shell Style Guide enforces strict lexical scoping rules to prevent namespace collision and state corruption.

*   **Locals (Bash):** Always use `local` (or `declare`) for variables inside functions. Name them using `lower_snake_case`. 
*   **Constants & Globals:** Name them using `UPPER_SNAKE_CASE`. Use `readonly` for constants to enforce immutability (`readonly MAX_RETRIES=5`).
*   **Environment Variables:** Exported variables should be `UPPER_SNAKE_CASE` (e.g., `SSH_AUTH_SOCK`).
*   **Fish Shell Nuances:** Fish abandons subshells for scope enforcement. Use `set -l var_name` for true locals, `set -g` for explicit globals, and `set -U` for persistent universal variables.

---

## 2. Error Handling, Safety & Cleanup
Robust automation requires adopting defensive programming techniques—what is colloquially known as **Bash Strict Mode**.

*   **Strict Mode Configuration:** `set -euo pipefail`
    *   `-e`: Exit immediately if a pipeline returns a non-zero status.
    *   `-u`: Treat unset variables as an error.
    *   `-o pipefail`: Return the exit status of the last command in the pipe that failed.
*   **Idempotent Cleanup (`trap`):**
    Resource leaks (file descriptors, temporary files) are catastrophic. Always use a `trap` for cleanup on `EXIT`, `ERR`, `INT`, and `TERM`.
    ```bash
    readonly TMP_DIR=$(mktemp -d)
    trap 'rm -rf "${TMP_DIR}"; exit' EXIT ERR INT TERM
    ```

---

## 3. Idempotent & Efficient Polling Mechanisms
Aggressive CPU spinning (`while true; do ... sleep X; done`) is an anti-pattern. Enterprise-grade architecture demands **event-driven** wait mechanics:

*   **Hardware / File System Events:** Use `inotifywait` (Linux) or `fswatch` (macOS/BSD) to block execution until a filesystem mutation occurs.
*   **Protocol-Aware Extraction:** When dealing with UNIX sockets like `SSH_AUTH_SOCK`, `awk` or `cat` cannot parse binary streams. The native protocol tool (`ssh-add -L`) must be used.
*   **State Polling Fallback:** When a state change happens *inside* a memory process (like a Secure Enclave key generation appearing in `ssh-agent`), `fswatch` cannot detect it. In such cases, polling the protocol (`ssh-add -L`) with a defined `sleep` is acceptable, provided it is wrapped in a bounded retry loop or explicitly waiting for manual user interaction (Hardware Security Boundary).

---

## 4. Etalon Structure for Automation Scripts
All `.mise/tasks/` must follow this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Constants
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly TARGET_FILE="${REPO_ROOT}/config.txt"

# 2. Cleanup / Trap
cleanup() {
    # Revert state or delete temp files
    :
}
trap cleanup EXIT ERR INT TERM

# 3. Logical Blocks
extract_data() {
    local target_dir
    target_dir=$(dirname "${TARGET_FILE}")
    # ... logic ...
}

# 4. Entrypoint
main() {
    extract_data
}

main "$@"
```
