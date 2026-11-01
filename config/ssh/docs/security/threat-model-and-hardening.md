# Threat Modeling & Defense-in-Depth Hardening
### Path: `~/.ssh/docs/security/threat-model-and-hardening.md`

---

## 1. Threat Matrix & MITRE ATT&CK Mapping

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                                 SSH THREAT TAXONOMY                                      │
├───────────────────────────────┬────────────────────────────┬─────────────────────────────┤
│ Vector / Technique            │ MITRE ATT&CK Reference     │ Defense-in-Depth Control    │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 1. Terrapin Prefix Truncation │ T1557 (Adversary-in-the-   │ AES-GCM Cipher Priority +   │
│    (CVE-2023-48795)           │ Middle)                    │ Strict KEX (RFC 5647)       │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 2. Keystroke Inter-Arrival    │ T1040 (Network Sniffing) / │ ObscureKeystrokeTiming yes  │
│    Timing Analysis            │ T1056 (Input Capture)      │ (20ms quantization + chaff) │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 3. SSH Agent Hijacking        │ T1185 (Browser/Agent Hijack│ ForwardAgent no +           │
│    & Forwarding Oracle        │ / Oracle Misuse)           │ ProxyJump (Layer 4 TCP)     │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 4. PKCS#11 Provider Injection │ T1203 (Exploitation for    │ ForwardAgent no +           │
│    (CVE-2023-38408)           │ Client Execution)          │ ssh-agent -P allowlisting   │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 5. Store-Now-Decrypt-Later    │ T1557 / Cryptanalytic      │ Hybrid ML-KEM-768 (FIPS 203)│
│    (Quantum Harvesting)       │ Quantum Adversary          │ + WarnWeakCrypto yes        │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 6. Stale Multiplexing Sockets │ T1071 (Application Layer   │ ChannelTimeout session=15m  │
│    & Zombie Channels          │ Protocol Misuse)           │ direct-tcpip=30m fwd=30m    │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 7. Rogue Host Key MITM        │ T1557 (Spoofing & Poison)  │ StrictHostKeyChecking +     │
│                               │                            │ VisualHostKey + UpdateHostKeys│
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 8. Silent Tunnel Fallback     │ T1090 (Proxy) /            │ ExitOnForwardFailure yes    │
│    (Port Collision Hijack)    │ T1557 (Interception)       │ (RFC 4254 §7.2 Fail-Close)  │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 9. Weak RSA Factorization     │ T1588.003 (Weak Crypto)    │ RequiredRSASize 4096        │
│    (Legacy Modulus Attacks)   │                            │ (Mozilla Hardened / 4K-bit) │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 10. Hostbased Trust Abuse     │ T1078 (Valid Accounts) /   │ HostbasedAuthentication no  │
│     (Rhosts / shosts bypass)  │ T1556 (Modify Auth Process)│ (RFC 4252 Strict Pubkey)    │
├───────────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ 11. Rogue TUN/TAP Injection   │ T1572 (Protocol Tunneling) │ Tunnel no                   │
│     (Unintended L3 routing)   │                            │ (RFC 4254 §7 Strict Disable)│
└───────────────────────────────┴────────────────────────────┴─────────────────────────────┘
```

---

## 2. In-Depth Threat Analysis

### 2.1 Terrapin Attack (CVE-2023-48795)
* **Mechanics**: Exploits RFC 4253 sequence counter unreset across symmetric encryption barriers. In `chacha20-poly1305` and EtM MACs, sequence numbers are used directly in tag generation. An active MitM can inject handshake packets and drop initial encrypted extension packets (`SSH_MSG_EXT_INFO`) without triggering integrity verification failures.
* **Impact**: Silently disables protocol extensions, downgrading authentication mechanisms or disabling keystroke timing defenses.
* **Remediation**:
  1. OpenSSH 10.5 automatically sends `kex-strict-c-v00@openssh.com`.
  2. Prioritizing `aes256-gcm@openssh.com` ensures mathematical immunity (RFC 5647 §7.1) even against non-compliant or intermediate legacy proxies.

### 2.2 Keystroke Timing Attacks (Dawn Song et al. 2001)
* **Mechanics**: Real-time SSH sessions transmit keystrokes in individual packets with minimal latency (`TCP_NODELAY`). Measuring packet inter-arrival times (IAT) reveals inter-key distances on standard keyboards, leaking:
  * Password character lengths during interactive `sudo` / `su` prompts.
  * Shell command syntax patterns.
* **Remediation**:
  `ObscureKeystrokeTiming yes` (RFC 4253 §10 / OpenSSH 9.5+).
  Buffers keystrokes and dispatches packets only on 20ms boundaries while injecting dummy ("chaff") packets after typing ceases. Overridden to `no` for non-interactive Git transport (`Host github.com`) to eliminate bulk data overhead.

### 2.3 SSH Agent Hijacking vs. ProxyJump
* **Threat**: Enabling `ForwardAgent yes` creates an agent UNIX domain socket on the remote server (`/tmp/ssh-XXXXXX/agent.<pid>`). Any root or same-UID process on that machine can issue signature requests across the network, turning the victim's agent into a signing oracle for lateral movement.
* **Remediation**:
  * Set `ForwardAgent no` globally.
  * Use **`ProxyJump` (`-J`)** for multi-hop bastion architectures. The jump host acts strictly as a Layer 4 TCP proxy (`ssh -W`). Encryption remains strictly end-to-end between client and destination; no agent socket is ever exposed on the bastion.

### 2.4 Cryptographic Forward Secrecy & Channel Inactivity
* **Threat**: Long-lived multiplexed connections (`ControlPersist 10m`) generate high volumes of ciphertext under a single symmetric key. If an adversary compromises memory, all session data encrypted with that key is exposed.
* **Remediation**:
  * `RekeyLimit 1G 1h`: Mandates key renegotiation every 1GB or 1 hour (RFC 4253 §9).
  * `ChannelTimeout session=15m direct-tcpip=30m forwarded-tcpip=30m`: Automatically tears down abandoned interactive shells, background local forwards (`-L`), and reverse tunnels (`-R`) (RFC 4254 §5.3).

### 2.5 Silent Port Forwarding Failure & Fallback Attacks
* **Threat**: By default (`ExitOnForwardFailure no`), if a requested port forward cannot be bound (e.g. port `5432` is already occupied by a rogue local process), OpenSSH logs a single warning to `stderr` and continues establishing the interactive shell. Scripts or automated pipelines relying on the tunnel proceed to transmit plaintext or connect to the untrusted local socket.
* **Remediation**:
  * `ExitOnForwardFailure yes` (RFC 4254 §7.2): Forces OpenSSH to abort immediately with exit code 255 if any local or remote forwarding fails, enforcing a fail-closed boundary.

### 2.6 Weak RSA Modulus Factorization
* **Threat**: Legacy network devices or compromised servers may offer 1024, 2048, or 3072-bit RSA host keys that can be factored using Number Field Sieve (NFS) algorithms or cloud GPU clusters.
* **Remediation**:
  * `RequiredRSASize 4096` (RFC 8332 / Mozilla Hardened Standard): Hardens the client parser to reject handshakes with RSA keys below 4096 bits. Guarantees maximum classical resistance across any legacy fallback.

### 2.7 Store-Now-Decrypt-Later (SNDL) & Quantum Harvest Auditing
* **Threat**: Encrypted sessions negotiated over classical KEX (Curve25519, ECDH P-256) are captured by state-sponsored surveillance and stored until a Cryptographically Relevant Quantum Computer (CRQC) using Shor's algorithm can decrypt them.
* **Remediation**:
  * Prioritize `mlkem768x25519-sha256` (NIST FIPS 203).
  * `WarnWeakCrypto yes` (OpenSSH 10.1+): Emits a high-visibility terminal warning if a server forces negotiation down to a non-PQC algorithm.
