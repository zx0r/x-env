# Research Report: OpenSSH Client Hardening and PQC Transition in 2026

## Executive Summary

This research investigates the best practices and contemporary configuration directives for the OpenSSH client (`ssh_config`) as of mid-2026. The analysis centers on the post-quantum cryptography (PQC) transition, granular connection lifecycle management, and client hardening against statistical network traffic analysis.

* **Default Post-Quantum Transition:** Starting with OpenSSH 10.0, the hybrid key encapsulation mechanism `mlkem768x25519-sha256` became the default standard, replacing classical `curve25519-sha256` to secure sessions against future decryption by cryptographically relevant quantum computers [1]. OpenSSH 10.4 introduced experimental support for composite digital signatures (`mldsa44-ed25519`) [4].
* **Weak Cryptography Guardrails:** The `WarnWeakCrypto` directive introduced in OpenSSH 10.1 actively emits terminal warnings when a remote server negotiates insecure or non-post-quantum algorithms, directly addressing the Store-Now-Decrypt-Later (SNDL) threat model [2], [10].
* **Granular Channel Inactivity Control:** The `ChannelTimeout` directive permits independent inactivity lifetimes across channel types (X11, TCP port forwarding, interactive sessions), superseding legacy and inefficient keep-alive polling via `ClientAlive*` or `ServerAlive*` [5], [9].
* **Side-Channel Timing Defenses:** The activation of `ObscureKeystrokeTiming` masks keystroke inter-arrival patterns via 20ms packet quantization and decoy chaff packets, neutralizing passive traffic analysis [1], [5].

**Primary Recommendation:** DevSecOps and systems engineers must configure `ssh_config` with hybrid key exchange prioritization (`mlkem768x25519-sha256`), enforce DNSSEC/SSHFP host verification, declare granular inactivity timeouts via `ChannelTimeout`, and activate `WarnWeakCrypto` to audit non-PQC session negotiations [1], [2], [5].

**Confidence Level:** High. The findings are based on official OpenBSD release announcements (10.0–10.4), NIST FIPS 203/204 specifications, and local runtime verification on Apple Silicon macOS endpoints.

---

## Introduction

### Research Question
How should the OpenSSH client configuration (`ssh_config`) be architected and hardened in mid-2026 to guarantee resilience against quantum adversaries (Zero Trust alignment) and prevent side-channel leakage without breaking transport stability?

This inquiry is essential within Zero Trust architectures anticipating the arrival of quantum cryptanalysis, where classical asymmetric systems (RSA, ECDSA) face structural compromise.

### Scope & Methodology
This investigation evaluates the following technical domains:
* Cryptographic evolution across OpenSSH releases 9.9, 10.0, 10.1, 10.2, 10.3, and 10.4 (2024–2026).
* Protocol integration of NIST standards FIPS 203 (ML-KEM) and FIPS 204 (ML-DSA).
* Granular channel lifecycle management and keystroke timing obfuscation.
* Host platform compatibility on macOS Sequoia (OpenSSH 10.x with LibreSSL).

Methodology relies on comparative analysis of OpenBSD source trees, official release notes, NIST publications, and local syntax evaluation via `ssh -G`. A total of 10 primary sources were triangulated.

### Key Assumptions
* **Assumption 1 (Server PQC Capability):** Target infrastructure servers are upgraded to OpenSSH 9.9+ and support hybrid key agreement. If an endpoint is unpatched, the client emits a warning without mandatory session termination unless explicitly enforced for classified segments.
* **Assumption 2 (Hardware-Backed Identity):** User authentication utilizes FIDO2 hardware security keys or GnuPG/Secure Enclave agent routing, eliminating plaintext private keys on persistent storage.
* **Assumption 3 (Local Runtime):** The local macOS workstation runs OpenSSH 10.0+, enabling modern parser directives.

---

## Main Analysis

### Finding 1: Key Exchange Algorithms and Post-Quantum Cryptography Transition
The adoption of hybrid key encapsulation mechanisms is the central pillar of SSH protocol evolution in 2026. According to the OpenSSH 10.0 release specification [1], `mlkem768x25519-sha256` became the default KEX preference. This scheme combines:
* **ML-KEM-768:** A lattice-based key encapsulation mechanism standardized in NIST FIPS 203 [6] based on the Module Learning with Errors (M-LWE) problem.
* **X25519:** Classical ECDH over Curve25519.

This hybrid model guarantees that the session remains confidential unless both elliptic-curve discrete logarithms and lattice problem hardness are solved simultaneously.

OpenSSH 10.1 introduced the `WarnWeakCrypto` directive [2]. Enabled by default (`yes`), it outputs an interactive diagnostic warning whenever connection negotiation completes without post-quantum forward secrecy [2], [10]. This alerts operators to passive Store-Now-Decrypt-Later (SNDL) collection risks. Legacy Diffie-Hellman groups and SHA-1 exchange modes are strictly deprecated [8].

**Key Evidence:**
* OpenSSH 10.0 prioritizes `mlkem768x25519-sha256` by default [1].
* OpenSSH 10.1 `WarnWeakCrypto` warns on non-PQC connections [2].
* NIST FIPS 203 provides formal hardness bounds for M-LWE against Shor's algorithm [6].

**Implications:**
Explicitly declaring `mlkem768x25519-sha256` and `sntrup761x25519-sha512@openssh.com` at the top of `KexAlgorithms` establishes robust quantum-safe guarantees. Activating `WarnWeakCrypto yes` ensures observability when connecting to legacy third-party hosts.

**Sources:** [1], [2], [6], [8], [10]

---

### Finding 2: Host Key and Public Key Signature Algorithms
While post-quantum key exchange (KEX) is standardized and operational by default, post-quantum digital signatures for host and user authentication remain in transitional adoption. OpenSSH 10.4 introduced experimental support for `mldsa44-ed25519` [4], combining NIST FIPS 204 ML-DSA (Crystals-Dilithium) [7] with Ed25519.

However, because this algorithm is experimental, it is not enabled by default. Generating compatible keys requires `ssh-keygen -t mldsa44-ed25519` [4]. In heterogeneous fleets, configurations must partition bleeding-edge algorithms: including `mldsa44-ed25519` in active `HostKeyAlgorithms` on clients running OpenSSH < 10.4 triggers a fatal parser termination: `Bad key types` [4], [5].

**Key Evidence:**
* OpenSSH 10.4 requires explicit opt-in for `mldsa44-ed25519` in `HostKeyAlgorithms` and `PubkeyAcceptedAlgorithms` [4].
* Clients running OpenSSH < 10.4 crash immediately if encountering unrecognized key algorithm tokens [5].
* NIST FIPS 204 establishes ML-DSA as the primary federal digital signature standard [7].

**Implications:**
Configurations must restrict active signature suites to proven standards (`ssh-ed25519`, `rsa-sha2-512`), gating experimental ML-DSA tokens behind version-checked environments or comments until client fleets upgrade globally.

**Sources:** [4], [5], [7]

---

### Finding 3: Inactivity and Session Timeout Management
Connection lifecycle governance transitioned from network-level keep-alive polling to granular channel lifecycle policies with the introduction of `ChannelTimeout` in OpenSSH 9.2 [9]. Historically, reliance on `ServerAliveInterval` kept idle shells and neglected port forwards open indefinitely, expanding the attack surface on unattended endpoints [9].

`ChannelTimeout` permits independent inactivity policies per channel type (interactive `session`, X11 forwarding, or `direct-tcpip` / `forwarded-tcpip` tunnels) [5], [9]. Importantly, `ssh_config` supports only `ChannelTimeout`. Attempting to declare `UnusedConnectionTimeout` (which is server-only) in a client configuration causes a fatal parser exit: `Bad configuration option: unusedconnectiontimeout` [5]. Syntax mandates space-separated name-value pairs (`type=interval`) [5].

**Key Evidence:**
* `ChannelTimeout` accepts space-separated `type=interval` assignments [5].
* `UnusedConnectionTimeout` is restricted to `sshd_config`; client usage aborts parsing [5], [9].
* OpenBSD manual specifications mandate spaces over commas for channel timeout parameters [5].

**Implications:**
Hardened client configurations must implement `ChannelTimeout` to automatically terminate neglected TCP tunnels without severing active interactive shells. `UnusedConnectionTimeout` must be omitted from client files.

**Sources:** [5], [9]

---

### Finding 4: Side-Channel Timing Defenses, Multiplexing, and Agent Sandboxing
Client security mandates defense against statistical traffic analysis. The `ObscureKeystrokeTiming` directive (OpenSSH 9.5+, refined in 10.0+) buffers interactive keystrokes and dispatches packets at fixed 20ms intervals, injecting decoy ("chaff") packets when idle [1], [5]. This prevents eavesdroppers from inferring command syntax or password lengths via packet inter-arrival time (IAT) analysis [1].

Man-in-the-Middle (MitM) resistance requires strict host key enforcement (`StrictHostKeyChecking ask`) and DNSSEC SSHFP validation (`VerifyHostKeyDNS yes`) [5], [8]. Agent hijacking is mitigated by disabling forwarding globally (`ForwardAgent no`) and restricting credentials with `IdentitiesOnly yes` [5], [8]. Binding `IdentityAgent` to a dedicated local socket isolates credentials inside hardware tokens [8].

**Key Evidence:**
* `ObscureKeystrokeTiming` implements 20ms packet quantization with idle chaff generation [1], [5].
* Mozilla guidelines enforce `IdentitiesOnly yes` to prevent authentication enumeration and agent exhaustion [8].
* `UpdateHostKeys ask` enables authenticated host key rotation with client confirmation [5].

**Implications:**
Combining `ObscureKeystrokeTiming`, `VerifyHostKeyDNS`, `IdentitiesOnly`, and hardware agent routing establishes multi-layered defense across transport and application boundaries.

**Sources:** [1], [5], [8]

---

## Synthesis

### Patterns Identified

#### Convergence of Client and Server Timeout Governance
Client configurations are increasingly adopting Zero Trust principles previously restricted to servers. Implementing `ChannelTimeout` in `ssh_config` places responsibility on the client endpoint to eliminate orphaned database tunnels and stale forwarded sockets.

#### Prudent Post-Quantum Hybridization
The OpenSSH engineering team enforces hybrid key agreements (`ML-KEM + X25519`) rather than pure post-quantum algorithms. This defense-in-depth model ensures that if mathematical flaws emerge in newly standardized lattice cryptosystems, classical elliptic curve cryptography continues to preserve session confidentiality.

### Novel Insights

#### Parser Rigidity in Heterogeneous Fleets
Because the OpenSSH parser validates all algorithm tokens globally at initialization (even inside inactive conditional blocks), backward compatibility cannot be achieved using a single monolithic configuration containing OpenSSH 10.4+ features on older clients. Configurations must be managed through modular layers or templated deployment pipelines.

### Implications

#### Platform Engineering (macOS & Unix Workstations)
Configurations must be strictly modularized. Hardcoding unsupported experimental ciphers on systems running OpenSSH 10.2p1 causes instant failures across `git`, terminal sessions, and automated background jobs.

#### Network Throughput & Mobile Constraints
`ObscureKeystrokeTiming` introduces continuous chaff traffic. While negligible on high-speed connections, it can degrade high-throughput non-interactive transfers (e.g. `git clone` or bulk SFTP). It should be selectively disabled for automated VCS endpoints (`Host github.com`).

---

## Limitations

### Counterevidence Register
* **Keep-Alives vs. Channel Inactivity:** Relying solely on `ServerAliveInterval` maintains NAT state but prevents resource reclamation. Conversely, overly aggressive `ChannelTimeout` settings terminate long-running queries over forwarded database connections. Resolution: use keep-alives for baseline transport continuity, paired with moderate (30m) channel timeouts for forwarded TCP tunnels.

### Known Gaps
* **Absence of ML-DSA in Stable Distributions:** As of 2026, enterprise Linux distributions (RHEL, Debian) ship OpenSSH 9.x/10.1 without ML-DSA support. Public key authentication must remain grounded in `ssh-ed25519` until upstream packaging catches up.

### Areas of Uncertainty
* The maturity of FIDO2 hardware tokens implementing lattice-based ML-DSA signatures remains limited, with full hardware availability expected in 2027+.

---

## Recommendations

### Immediate Actions
1. **Enforce Correct `ChannelTimeout` Syntax:** Ensure parameters use space separators: `ChannelTimeout session=15m direct-tcpip=30m forwarded-tcpip=30m`. Exclude `UnusedConnectionTimeout`.
2. **Gate Experimental Signatures:** Keep `mldsa44-ed25519` documented or commented out on clients running OpenSSH < 10.4 to prevent fatal startup crashes.
3. **Optimize Git Endpoints:** Disable keystroke obscuration and DNSSEC SSHFP queries on `Host github.com` (`ObscureKeystrokeTiming no`, `VerifyHostKeyDNS no`) to eliminate latency overhead on bulk operations.

---

## Appendix: Methodology

### Research Pipeline
1. **Scope:** Define OpenSSH 10.x compatibility boundaries and cryptographic baselines.
2. **Plan:** Target release notes (10.0–10.4), RFCs, and NIST standards documents.
3. **Retrieve:** Extract verbatim technical specifications and parser constraints.
4. **Triangulate:** Cross-reference configuration syntax against `ssh -G` evaluation on macOS endpoints.

### Sources Consulted
* **Standards:** NIST FIPS 203 (ML-KEM), NIST FIPS 204 (ML-DSA).
* **Specifications:** RFC 4253, RFC 4254, RFC 5647, RFC 8332.
* **Official Releases:** OpenBSD / OpenSSH Release Notes (10.0, 10.1, 10.3, 10.4).
* **Hardening Guides:** Mozilla Infosec OpenSSH Guidelines, OpenBSD Manual (`ssh_config(5)`).

---

## Bibliography

[1] OpenBSD (2025). "OpenSSH 10.0 Release Notes". OpenBSD Foundation. - https://www.openbsd.org/openssh/txt/release-10.0  
[2] OpenSSH (2025). "OpenSSH 10.1 Release Notes". OpenSSH Project. - https://www.openssh.org/txt/release-10.1  
[3] OpenSSH Project (2026). "OpenSSH 10.3 Released Announcement". Mindrot Mailing List. - https://lists.mindrot.org/pipermail/openssh-unix-dev/2026-April/042418.html  
[4] OpenSSH (2026). "OpenSSH 10.4 Release Notes". OpenSSH Project. - https://www.openssh.org/txt/release-10.4  
[5] OpenBSD (2026). "OpenBSD ssh_config(5) Manual Page". OpenBSD Man Pages. - https://man.openbsd.org/ssh_config.5  
[6] NIST (2024). "NIST FIPS 203: Module-Lattice-Based Key-Establishment Mechanism Standard". National Institute of Standards and Technology. - https://csrc.nist.gov/pubs/fips/203/final  
[7] NIST (2024). "NIST FIPS 204: Module-Lattice-Based Digital Signature Standard". National Institute of Standards and Technology. - https://csrc.nist.gov/pubs/fips/204/final  
[8] Mozilla (2025). "Mozilla OpenSSH Hardening Guidelines". Mozilla Infosec. - https://infosec.mozilla.org/guidelines/openssh  
[9] StackExchange (2023). "Inactivity Timeouts vs. Connection Keep-Alives in OpenSSH". Unix & Linux StackExchange. - https://unix.stackexchange.com/questions/767493/issue-with-ssh-client-alive-interval-in-sshd-config  
[10] OpenSSH (2025). "OpenSSH Post-Quantum Cryptography Information". OpenSSH Security Portal. - https://openssh.com/pq.html  
