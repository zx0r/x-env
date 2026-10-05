# ---
# schema: "mdd-node-v1"
# id: ".meta/research_secure_enclave_automation.md"
# title: "Architectural Research: Secure Enclave Automation & Zero-Trust Secrets"
# layer: "Meta / Research"
# responsibility: "Documents state-of-the-art macOS Secure Enclave (SEP) automation capabilities and JIT API key injection patterns."
# status: "subsumed"
# subsumed_by: "zero_leakage_secrets_architecture.md"
# subsumed_note: "This 62-line document is a strict subset of zero_leakage_secrets_architecture.md (546 lines). Read that instead."
# dependencies: []
# backlinks: ["MAP_OF_CONTENT.md", "docs/SECURITY.md"]
# created_at: "2026-09-22"
# updated_at: "2026-10-04"
# tags: ["architecture", "secure-enclave", "macos", "jit-secrets", "zero-trust", "historical"]
# ---

# 2026 State-of-the-Art macOS Secure Enclave & Zero-Trust Cryptography

**Date:** 2026-09-22
**Domain:** Hardware Identity & Secrets Management

This report synthesizes deep research into macOS Secure Enclave (SEP) automation and zero-trust shell environment practices for macOS Darwin 26/27 (2026).

## 1. Automated macOS Secure Enclave (SEP) Key Generation

Historically, applications like **Secretive** mandated GUI interaction and Touch ID biometric validation to generate and use SEP-backed SSH keys. 

### Native CLI Automation (CryptoTokenKit)
In 2026, macOS provides native CryptoTokenKit (CTK) support for Secure Enclave identities that can be manipulated entirely via the CLI using the Smart Card Authentication tool (`sc_auth`).

To generate an un-exportable (`p-256-ne`) key inside the SEP **without** biometric protection (for unattended agents/CI):
```bash
sc_auth create-ctk-identity -l "automated-agent-key" -k p-256-ne
```
To export the resident key handle for SSH:
```bash
ssh-keygen -w /usr/lib/ssh-keychain.dylib -K -N ""
```

**Architectural Decision for X-ENV:** 
While native CLI creation is possible, the X-ENV paradigm explicitly **requires biometric user presence (Touch ID)** for Tier 1 Git commit signing to ensure non-repudiation. Therefore, the architecture retains **Secretive** as the hardware bridge, accepting the minor tradeoff of a one-time GUI interaction during workstation bootstrap, managed via an idempotent polling script.

## 2. Zero-Trust API Key Handling: JIT Injection

Are Just-In-Time (JIT) Keychain injection and `set -lx` considered state-of-the-art for preventing memory/env siphoning? **Yes.**

Modern zero-trust shell environments dictate that sensitive credentials (e.g., OpenAI or Anthropic API keys) should never reside in global shell environments (`~/.bashrc`, `~/.zshrc`, or global `export`s) where they can be siphoned by rogue child processes (`npm install`, `cargo build`) traversing `KERN_PROCARGS2`.

### Ephemeral Environment Scoping (Fish Shell)
In Fish shell, using `set -lx` (local export) or inline assignment is the definitive standard.

**Block-scoped Injection:**
```fish
function run_ai_agent
    # -l: local to this block, -x: export to child process
    set -lx OPENAI_API_KEY (security find-generic-password -w -s "OpenAI_API")
    command ai_agent $argv
end
# OPENAI_API_KEY is entirely erased from memory/env outside this function
```

### Why this prevents siphoning:
1. **No Global Persistence:** The API key is never attached to the parent shell's global environment (`set -g`), meaning background jobs or telemetry scripts running in the same shell cannot read the key.
2. **Process Isolation:** The key is passed directly via `execve` environment variables to the specific child process, effectively isolating the secret from lateral discovery.
