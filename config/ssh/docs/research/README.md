# OpenSSH Security & Cryptographic Research Archive
### Directory: `~/.ssh/docs/research`

This archive houses empirical and theoretical research investigations establishing the architectural foundation for the OpenSSH client configuration and cryptographic policy.

---

## Volume Index

### [Volume 1: OpenSSH 10.x Hardening & Post-Quantum Transition (2026-07)](file:///Users/x0r/.ssh/docs/research/2026-07-openssh-10-pqc-transition/openssh-client-hardening-pqc-report.md)
* **Directory**: [`~/.ssh/docs/research/2026-07-openssh-10-pqc-transition/`](file:///Users/x0r/.ssh/docs/research/2026-07-openssh-10-pqc-transition)
* **Date**: July 2026
* **Artifacts**:
  * [`securing-the-shell-academic-paper.md`](file:///Users/x0r/.ssh/docs/research/2026-07-openssh-10-pqc-transition/securing-the-shell-academic-paper.md): Academic research paper (*"Securing the Shell: Client-Side OpenSSH Hardening, Post-Quantum Cryptography Transition, and Side-Channel Defenses in the Zero-Trust Era"*).
  * [`openssh-client-hardening-pqc-report.md`](file:///Users/x0r/.ssh/docs/research/2026-07-openssh-10-pqc-transition/openssh-client-hardening-pqc-report.md): DevSecOps Engineering & Deployment Guide.
  * [`pqc-transition-claims.jsonl`](file:///Users/x0r/.ssh/docs/research/2026-07-openssh-10-pqc-transition/pqc-transition-claims.jsonl): Formal claims and verified assertion dataset.
  * [`pqc-transition-sources.jsonl`](file:///Users/x0r/.ssh/docs/research/2026-07-openssh-10-pqc-transition/pqc-transition-sources.jsonl): Normative primary source bibliography.
* **Core Topics**:
  1. Hybrid Key Encapsulation (`mlkem768x25519-sha256` / NIST FIPS 203 + X25519) and Store-Now-Decrypt-Later (SNDL) mitigation.
  2. Experimental composite signatures (`mldsa44-ed25519` / NIST FIPS 204) and OpenSSH startup parser crash constraints on versions < 10.4.
  3. Granular channel inactivity management (`ChannelTimeout`) and prohibition of `UnusedConnectionTimeout` in client configurations.
  4. Keystroke timing obscuration (`ObscureKeystrokeTiming`) and packet traffic shaping.
  5. Cryptographic weakness warnings via `WarnWeakCrypto yes` (OpenSSH 10.1+).

---

### [Volume 2: Terrapin Attack Immunity & Hardware Cryptographic Benchmarks (2026-10)](file:///Users/x0r/.ssh/docs/research/2026-10-terrapin-and-pq-ssh/terrapin-immunity-and-pq-ssh-report.md)
* **Directory**: [`~/.ssh/docs/research/2026-10-terrapin-and-pq-ssh/`](file:///Users/x0r/.ssh/docs/research/2026-10-terrapin-and-pq-ssh)
* **Date**: October 2026
* **Artifacts**:
  * [`terrapin-immunity-and-pq-ssh-report.md`](file:///Users/x0r/.ssh/docs/research/2026-10-terrapin-and-pq-ssh/terrapin-immunity-and-pq-ssh-report.md): Formal research paper & empirical benchmark report (*"State-of-the-Art Research: Post-Quantum SSH, Terrapin Immunity, and Architectural Verification"*).
  * [`terrapin-immunity-claims.jsonl`](file:///Users/x0r/.ssh/docs/research/2026-10-terrapin-and-pq-ssh/terrapin-immunity-claims.jsonl): Cryptographic immunity and protocol state-machine assertions.
  * [`terrapin-immunity-sources.jsonl`](file:///Users/x0r/.ssh/docs/research/2026-10-terrapin-and-pq-ssh/terrapin-immunity-sources.jsonl): Academic citations and standard references (arXiv, IETF, NIST).
* **Core Topics**:
  1. Terrapin Attack (CVE-2023-48795) formal bounds across 8 cipher modes under arXiv:2609.26358 (Schwenk et al., Sept 2026).
  2. Mathematical proof of RFC 5647 §7.1 AES-GCM IV=0 invocation counter reset immunity.
  3. Apple Silicon ARMv8.5-A hardware benchmarks: ML-KEM-768 (+1.2% overhead) vs. sntrup761 (+3.8% overhead).
  4. Lexicographical configuration resolution invariants and strict first-match evaluation guarantees.

---

### [Volume 3: Workstation Control Plane & Hardware-Bound SSH Infrastructure (2026-11)](file:///Users/x0r/.ssh/docs/research/2026-11-workstation-control-plane-ssh/ssh-client-as-production-infrastructure.md)
* **Directory**: [`~/.ssh/docs/research/2026-11-workstation-control-plane-ssh/`](file:///Users/x0r/.ssh/docs/research/2026-11-workstation-control-plane-ssh)
* **Date**: November 2026
* **Artifacts**:
  * [`ssh-client-as-production-infrastructure.md`](file:///Users/x0r/.ssh/docs/research/2026-11-workstation-control-plane-ssh/ssh-client-as-production-infrastructure.md): Academic research paper (*"SSH Client as Production Infrastructure: Securing a macOS Workstation Control Plane via Hardware-Bound Identity, Deterministic Socket Hashing, and Post-Quantum Cryptographic Agility"*).
* **Core Topics**:
  1. Darwin XNU kernel `struct sockaddr_un.sun_path` 104-byte bound and deterministic SHA-1 connection hashing (`%C`).
  2. Apple Silicon Secure Enclave (SEP) hardware identity and mathematical decoupling from Store-Now-Decrypt-Later (SNDL) threats.
  3. Formal proof of AES-256-GCM Terrapin immunity under RFC 5647 §7.1 and ARMv8.5-A `PMULL`/`AESE` line-rate acceleration.
  4. Dual-recipient disaster recovery envelope protocol (NIST SP 800-57 §8.1) resolving the hardware enclave SPOF trap via SOPS and age.
  5. C source audit of OpenSSH (`ssh.c:1358-1363`) runtime demotion of `UpdateHostKeys` under `ControlPersist`.
