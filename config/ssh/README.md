# OpenSSH Client Architecture & Cryptographic Verification
### Platform : macOS Sequoia (Apple Silicon arm64 Darwin 25+)
### Standards: OpenSSH 10.5+ | FIPS 203 (ML-KEM) | Terrapin Mitigated (RFC 5647) | BSI TR-02102-4
### Toolchain: Apple Secure Enclave (Secretive) | SOPS | age | Kitty | Tmux | Fish Shell

---

## 1. System Overview & Architectural Invariants

Secure Shell (SSH) is the foundational transport layer for remote systems administration, Git version control, and infrastructure orchestration. Default SSH configurations leave developer workstations vulnerable to critical threats: software private keys stored in plaintext on disk, stale UNIX socket descriptors in tmux panes, terminfo incompatibilities in GPU terminals, and socket pathname buffer overflows in the macOS Darwin XNU kernel.

This architecture enforces four core invariants:
1. **Hardware-Rooted Cryptographic Identity**: Apple Silicon Secure Enclave Processor (SEP) biometric gating (Touch ID) via **Secretive**, rendering private keys physically non-exportable.
2. **Post-Quantum Wire Transport & Terrapin Immunity**: Hybrid **ML-KEM-768 + X25519** (FIPS 203) key exchange and hardware-accelerated **AES-GCM** AEAD ciphers (RFC 5647), neutralizing both Store-Now-Decrypt-Later (SNDL) and Terrapin (CVE-2023-48795) sequence truncation attacks.
3. **Darwin 104-Byte `sockaddr_un` Safety**: Connection multiplexing with deterministic 40-character SHA1 hashed control paths (`ControlPath ~/.ssh/cm-%C`), permanently preventing XNU kernel socket overflows.
4. **Lexicographical Precedence Integrity**: Strict numeric file ordering (`01-79` host overrides before `80-99` global defaults), ensuring OpenSSH first-match-wins evaluation rules are preserved without configuration shadowing.

---

## 2. Threat Modeling & Cryptographic Proofs

### 2.1 Terrapin Attack Immunity & Cipher Precedence (USENIX Security 2024 / arXiv:2609.26358)
The Terrapin attack (CVE-2023-48795) exploits two structural mechanisms in RFC 4253:
1. Pre-authentication informational packets (`SSH_MSG_IGNORE`, `SSH_MSG_DEBUG`) are unauthenticated.
2. Transport sequence numbers do **not** reset to zero upon symmetric key activation (`SSH_MSG_NEWKEYS`).

* **Vulnerability in ChaCha20-Poly1305 & EtM**: In `chacha20-poly1305@openssh.com` and all Encrypt-then-MAC (`*-etm`) modes, authentication tags cover the unreset sequence counter. An active network MitM can inject handshake packets to desynchronize sequence counters and subsequently drop `SSH_MSG_EXT_INFO`. The authentication tag validates successfully, allowing silent downgrades.
* **Mathematical Immunity of AES-GCM (RFC 5647 §7.1)**: Under RFC 5647, AES-GCM uses an independent 64-bit invocation counter (IV) that is **explicitly initialized to 0 upon `SSH_MSG_NEWKEYS`**. The invocation counter is decoupled from pre-authentication transport sequence numbers. Any packet drop or injection desynchronizes the GHASH counter, causing an immediate, fatal decryption tag failure.
* **Apple Silicon Hardware Acceleration**: On Apple Silicon M-series processors (ARMv8.5-A), AES-GCM is executed by dedicated hardware crypto instructions (`PMULL` + `AES`), delivering ~4x higher throughput and lower battery consumption compared to software-bound ChaCha20-Poly1305.
* **Standard**: `Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,chacha20-poly1305@openssh.com`.

### 2.2 Side-Channel Keystroke Timing Defense (Dawn Song et al. / OpenSSH 9.5+)
Interactive SSH sessions transmit keystrokes as individual packets immediately upon input (`TCP_NODELAY`).
* **Threat**: Statistical analysis of packet inter-arrival timing (IAT) leaks typing cadence, distinguishing password lengths during interactive `sudo` prompts and inferring shell command syntax.
* **Countermeasure**: `ObscureKeystrokeTiming yes` quantizes input transmission to fixed 20ms intervals and injects pseudo-random dummy ("chaff") packets after input stops, masking the user's typing rhythms.

### 2.3 Post-Quantum Hybrid Key Exchange (FIPS 203 ML-KEM)
* **Threat Model**: Adversaries harvesting encrypted network traffic today to decrypt once Cryptanalytically Relevant Quantum Computers (CRQC) become operational (Store-Now-Decrypt-Later).
* **Countermeasure**: OpenSSH 10.5 defaults to hybrid **`mlkem768x25519-sha256`**, combining Module Learning with Errors (ML-KEM-768) with classical X25519 ECDH. Both mathematical problems must be broken simultaneously to compromise the session key.

### 2.4 Lexicographical Include Precedence (OpenSSH RFC Rules)
* **Mechanism**: OpenSSH parses `Include conf.d/*.conf` in lexical order. For every parameter, **the first obtained value wins**.
* **Invariant**: If wildcard defaults (`Host *`) appear lexicographically before specific host blocks, all host-specific overrides are silently ignored. Host-specific files must be assigned lower numeric prefixes (`10-`, `20-`), while global defaults must be assigned higher numeric prefixes (`80-`, `90-`).

---

## 3. Directory & Modular File Architecture (`~/.ssh/`)

```
~/.ssh/
├── config                     # Entry point: IgnoreUnknown header + Include directive
├── config.monolithic.example  # Monolithic architecture reference config
├── allowed_signers            # OpenSSH PROTOCOL.sshsig trust store for Git signing
├── known_hosts                # Hashed remote host public keys
├── ssh_auth_sock              # Symlink -> Secretive Secure Enclave agent socket
├── zx0r_ecdsa-sha2-nistp256@github.pub  # Public hardware identity (Touch ID SEP)
├── conf.d/                    # Modular configuration layers (RFC 4251 Domains)
│   ├── 10_hosts.conf          # Target Scoping: VCS (GitHub) & Infrastructure (OpenWrt)
│   ├── 80_connection.conf     # RFC 4254 Connection Protocol: Multiplexing, Darwin cm-%C
│   ├── 85_authentication.conf # RFC 4252 User Authentication: Touch ID Enclave socket
│   └── 90_transport.conf      # RFC 4253 Transport Layer: Post-Quantum KEX, AES-GCM
└── docs/                      # Diátaxis Documentation Suite
    ├── architecture/          # System design & SOPS dual-recipient topology
    ├── security/              # Threat modeling, crypto standards & hardware parity
    ├── runbooks/              # Verification test suites & disaster recovery SOPs
    └── research/              # PQC transition, Terrapin immunity & academic proofs
```

---

## 4. Production Configuration Directives

### 4.1 Orchestrator: `~/.ssh/config`
```ssh
IgnoreUnknown UseKeychain
Include conf.d/*.conf
```

### 4.2 Target Scoping: `~/.ssh/conf.d/10_hosts.conf`
```ssh
# Section 1: Version Control & Developer Endpoints
Host github.com gist.github.com
    User git
    HostName github.com
    Port 22
    IdentityFile ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
    IdentitiesOnly yes
    AddKeysToAgent no
    UseKeychain yes
    PreferredAuthentications publickey

Host ssh.github.com *.ssh.github.com 443.github.com *.443.github.com
    User git
    HostName ssh.github.com
    Port 443
    IdentityFile ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
    IdentitiesOnly yes
    PreferredAuthentications publickey

Host github-443
    User git
    HostName ssh.github.com
    Port 443
    IdentityFile ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
    IdentitiesOnly yes
    PreferredAuthentications publickey

# Section 2: Local Infrastructure & Appliances
Host openwrt openwrt.lan
    HostName openwrt.lan
    User root
    Port 22
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
```

### 4.3 Connection Protocol (RFC 4254): `~/.ssh/conf.d/80_connection.conf`
```ssh
Host *
    ControlMaster auto
    ControlPersist 10m
    ControlPath ~/.ssh/cm-%C
    ChannelTimeout session=15m direct-tcpip=30m
    ServerAliveInterval 15
    ServerAliveCountMax 3
    TCPKeepAlive yes
    ClearAllForwardings yes
    ForwardAgent no
    ForwardX11 no
    ForwardX11Trusted no
    PermitLocalCommand no
    IPQoS lowdelay throughput
```

### 4.4 User Authentication Protocol (RFC 4252): `~/.ssh/conf.d/85_authentication.conf`
```ssh
Host *
    IdentityAgent ~/.ssh/ssh_auth_sock
    IdentitiesOnly yes
    AddKeysToAgent no
    UseKeychain yes
    PasswordAuthentication no
    KbdInteractiveAuthentication no
    PubkeyAuthentication yes
```

### 4.5 Transport Layer Protocol (RFC 4253): `~/.ssh/conf.d/90_transport.conf`
```ssh
Host *
    StrictHostKeyChecking ask
    HashKnownHosts yes
    VerifyHostKeyDNS yes
    VisualHostKey yes
    AddressFamily any
    ConnectTimeout 10
    Compression no
    LogLevel INFO
    ObscureKeystrokeTiming yes
    RekeyLimit 1G 1h

    KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
    Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes128-ctr
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
    HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,ssh-mldsa44-ed25519@openssh.com,ssh-mldsa44-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ecdsa-sha2-nistp256@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256
    PubkeyAcceptedAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,ssh-mldsa44-ed25519@openssh.com,ssh-mldsa44-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ecdsa-sha2-nistp256@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256
```


---

## 5. Secret Management Hardware Parity: SOPS & Apple Secure Enclave

### 5.1 The Threat Model & Non-Exportability Paradox
* **SSH Layer**: Protected by Apple Silicon Secure Enclave (Touch ID). Private keys cannot be extracted from silicon.
* **Secrets Layer**: Previously, the master age key was stored in plaintext in `~/.config/sops/age/keys.txt`, susceptible to userland exfiltration.
* **The Non-Exportability Paradox**: Moving solely to `age-plugin-se` achieves hardware-rooted biometric gating, but because Secure Enclave keys are hardware-bound and non-exportable, hardware destruction or logic board replacement causes **total, irrevocable loss of 100% of encrypted secrets**.

### 5.2 Enterprise Architecture: Dual-Recipient Disaster Recovery Protocol
All secrets are encrypted under a **Dual-Recipient Envelope Encryption Scheme** (NIST SP 800-57 Pt. 1 Rev. 5 / RFC 5647):
* **Primary Recipient (Hot / Operational)**: `age1se1qt9vr7cr7t3g95l8dy6ucxfl86ry7eqsjx5lypa3k23e2fxy0u7h2xj372y`
  * Apple Silicon Secure Enclave (`age-plugin-se`), gated by Touch ID / Biometrics.
  * Opaque handle `AGE-PLUGIN-SE-1...` persisted in `~/.config/sops/age/keys.txt` (permissions `0600`).
* **Recovery Recipient (Cold / Disaster Recovery)**: `age12q40mc59ccg6jraxrl62gju049pzucya76cjgjquen65zpaqzahqe3rlr4`
  * Offline Break-Glass Master Key (`age` X25519) stored in an encrypted air-gapped vault.

### 5.3 Declarative Production Rules (`~/.config/sops/.sops.yaml`)
```yaml
creation_rules:
  - path_regex: '.*(\.enc(\.|$)|secrets|vault|credentials).*'
    key_groups:
      - age:
          - 'age1se1qt9vr7cr7t3g95l8dy6ucxfl86ry7eqsjx5lypa3k23e2fxy0u7h2xj372y'
          - 'age12q40mc59ccg6jraxrl62gju049pzucya76cjgjquen65zpaqzahqe3rlr4'
    encrypted_regex: '(?i)(data|stringData|secret|password|passphrase|token|key|credential|cert|auth|vault|private)'
```

### 5.4 Operational & Recovery Runbooks
* Architectural Specification: [`docs/architecture/sops-dual-recipient-disaster-recovery.md`](file:///Users/x0r/.ssh/docs/architecture/sops-dual-recipient-disaster-recovery.md)
* Operational Runbook: [`docs/runbooks/sops-disaster-recovery.md`](file:///Users/x0r/.ssh/docs/runbooks/sops-disaster-recovery.md)
* Security Parity Analysis: [`docs/security/secret-management-parity.md`](file:///Users/x0r/.ssh/docs/security/secret-management-parity.md)

