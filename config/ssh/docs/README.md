# OpenSSH & Secrets Infrastructure Documentation
### Platform: macOS (Apple Silicon arm64, Darwin 25+)
### Standards: OpenSSH 10.5+ | RFC 4251 Protocol Domains | FIPS 203 | RFC 5647 | NIST SP 800-57 Pt. 1 Rev. 5
### Toolchain: Apple Secure Enclave (Secretive, age-plugin-se) | Mozilla SOPS 3.13+ | age 1.3+ | Fish Shell

---

## 1. Documentation Structure

This repository adheres to the **Diátaxis** documentation framework, segregating architectural blueprints, security threat models, cryptographic proofs, and operational runbooks:

```
~/.ssh/docs/
├── README.md                                 # Master Index & Standards Compliance
├── architecture/
│   ├── system-design.md                      # Modular Precedence, RFC Domain Decomposition, Darwin Socket Architecture
│   └── sops-dual-recipient-disaster-recovery.md # Dual-Recipient Disaster Recovery (Secure Enclave + Cold Key)
├── security/
│   ├── threat-model-and-hardening.md         # Threat Analysis, Terrapin (CVE-2023-48795), Side-Channels
│   ├── cryptographic-standards.md            # Post-Quantum FIPS 203/204, RFC 5647 AES-GCM Immunity, KEX/Ciphers
│   └── secret-management-parity.md           # Secure Enclave (Secretive) vs SOPS/age Hardware Parity
├── runbooks/
│   ├── verification-and-troubleshooting.md   # Live Audit Test Suite, Socket Recovery, Precedence Verification
│   └── sops-disaster-recovery.md             # SOPS Key-Wrapping, Break-Glass Ceremony, Key Rotation Procedures
└── research/                                 # Explanation: Deep Research & Formal Verification
    ├── README.md                             # Register & Topic Index
    ├── 2026-07-openssh-10-pqc-transition/   # Post-Quantum Transition Analysis & Formal Academic Paper
    └── 2026-10-terrapin-and-pq-ssh/          # Terrapin Immunity (RFC 5647) & ARMv8.5-A Benchmarks
```

---

## 2. Standards Compliance Matrix

| Regulatory / Technical Standard | Benchmark Level | Implementation in `~/.ssh/` & `~/.config/sops/` |
| :--- | :--- | :--- |
| **RFC 4251 Architecture** | Protocol Domain Partitioning | Strict separation of Target Scoping (`10_hosts.conf`), Connection (`80_connection.conf`), Authentication (`85_authentication.conf`), and Transport (`90_transport.conf`). |
| **NIST SP 800-131A Rev. 2** | Cryptographic Transitions | Transition from classical ECDH to Post-Quantum Hybrid (ML-KEM-768). Legacy 3DES, CBC, SHA-1 completely removed. |
| **NIST FIPS 203 (ML-KEM)** | Primary Post-Quantum KEX | `mlkem768x25519-sha256` prioritized as system default key exchange. |
| **NIST FIPS 204 (ML-DSA)** | Post-Quantum Digital Signatures | `ssh-mldsa44-ed25519@openssh.com` enabled in HostKeyAlgorithms & PubkeyAcceptedAlgorithms. |
| **RFC 5647 (AES-GCM for SSH)** | Terrapin (CVE-2023-48795) Mitigation | `aes256-gcm@openssh.com` prioritized over ChaCha20-Poly1305. Independent IV counter eliminates sequence truncation risks. |
| **NIST SP 800-57 Pt. 1 Rev. 5** | Cryptographic Key Management & DR | SOPS Dual-Recipient key grouping (Primary Secure Enclave + Cold Air-Gapped Disaster Recovery Key). |
| **Apple Secure Enclave (SEP)** | Hardware-Rooted Identity & Parity | SSH keys gated via Secretive; SOPS master encryption gated via `age-plugin-se` (Touch ID). |
| **BSI TR-02102-4 / ANSSI** | Session Rekeying & Forward Secrecy | `RekeyLimit 1G 1h` enforces continuous symmetric key rotation within persistent connections. |
| **IEEE S&P (Song et al.)** | Side-Channel Timing Defense | `ObscureKeystrokeTiming yes` masks packet inter-arrival intervals and injects chaff traffic. |
| **Apple Darwin Kernel Specification** | `sockaddr_un` 104-byte Safety | `ControlPath ~/.ssh/cm-%C` restricts UNIX socket path lengths to <= 59 bytes, preventing buffer overflows. |

---

## 3. Configuration Hierarchy & Domain Mapping

1. **[`~/.ssh/config`](file:///Users/x0r/.ssh/config)**: Entry point orchestrator with top-level `IgnoreUnknown` header and lexical `Include conf.d/*.conf`.
2. **[`~/.ssh/conf.d/10_hosts.conf`](file:///Users/x0r/.ssh/conf.d/10_hosts.conf)**: **Target Scoping Domain (`readconf.c`)** — Unified host profiles and overrides. Contains Section 1 (Git/VCS remotes: GitHub, Port 22/443, aliases) and Section 2 (Infrastructure: OpenWrt gateway `accept-new`). Evaluated first!
3. **[`~/.ssh/conf.d/80_connection.conf`](file:///Users/x0r/.ssh/conf.d/80_connection.conf)**: **RFC 4254 Connection Protocol Domain** — Connection multiplexing, Darwin safe socket hash (`cm-%C`), `ChannelTimeout`, and keepalive governance.
4. **[`~/.ssh/conf.d/85_authentication.conf`](file:///Users/x0r/.ssh/conf.d/85_authentication.conf)**: **RFC 4252 User Authentication Protocol Domain** — Hardware Secure Enclave routing (`IdentityAgent`), `IdentitiesOnly yes`, disabling password and interactive authentication.
5. **[`~/.ssh/conf.d/90_transport.conf`](file:///Users/x0r/.ssh/conf.d/90_transport.conf)**: **RFC 4253 Transport Layer Protocol Domain** — Post-Quantum ML-KEM-768 hybrid KEX, AES-GCM (Terrapin immune), EtM MACs, `ObscureKeystrokeTiming`, `RekeyLimit`, and host verification.
6. **[`~/.config/sops/.sops.yaml`](file:///Users/x0r/.config/sops/.sops.yaml)**: **SOPS Secrets Management Domain** — Declarative key groups enforcing Dual-Recipient envelope encryption (`age-plugin-se` + Cold Recovery Key).
