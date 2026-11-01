# Cryptographic Standards & Algorithm Specification
### Path: `~/.ssh/docs/security/cryptographic-standards.md`

---

## 1. Key Exchange Algorithms (KEX)

### 1.1 Post-Quantum Hybrid Architectures
All modern OpenSSH key exchange algorithms are **hybrids**, combining a classical elliptic curve key exchange (X25519) with a post-quantum Key Encapsulation Mechanism (KEM):

$$K_{\text{session}} = \text{KDF}(K_{\text{PQ}} \parallel K_{\text{Classical}} \parallel H(\text{transcript}))$$

* **Security Invariant**: The exchange remains secure against classical adversaries if X25519 holds, and secure against quantum adversaries if the PQ-KEM holds. Both must be compromised simultaneously to break session confidentiality.

### 1.2 Specification & Algorithm Ranking

```ssh
KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
```

1. **`mlkem768x25519-sha256` (NIST FIPS 203 ML-KEM)**:  
   Standardized in 2024, default in OpenSSH 10.0+. Based on Module Learning with Errors (MLWE) over cyclotomic rings (CRYSTALS-Kyber). Employs Number Theoretic Transforms (NTT) for high computational efficiency on modern ARM/x86 architectures (+1.2% overhead on Apple Silicon).
2. **`sntrup761x25519-sha512@openssh.com` (Streamlined NTRU Prime 761)**:  
   Introduced in OpenSSH 9.0. Operates over quotient polynomial rings $\mathbb{Z}_q[x]/(x^p - x - 1)$ to avoid cyclotomic structures. Retained as secondary fallback (+3.8% overhead).
3. **`curve25519-sha256` (RFC 8731)**:  
   Classical ECDH at 128-bit security level.
4. **`diffie-hellman-group16-sha512` & `group18-sha512` (RFC 3526)**:  
   Finite-field Diffie-Hellman groups (4096-bit and 8192-bit MODP) providing enterprise fallback.

---

## 2. Symmetric Ciphers (AEAD)

### 2.1 Protocol Immunity: AES-GCM vs. ChaCha20-Poly1305

```ssh
Ciphers aes256-gcm@openssh.com,aes128-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr,aes128-ctr
```

* **AES-GCM (RFC 5647 §7.1)**:  
  Maintains an independent 64-bit invocation counter (IV) that is **explicitly initialized to 0 upon `SSH_MSG_NEWKEYS`**. The counter is completely decoupled from transport sequence numbers. If an attacker injects or drops packets (Terrapin attack, CVE-2023-48795), the invocation counter desynchronizes immediately, causing GHASH authentication to fail.
* **ChaCha20-Poly1305 (RFC 8439 / OpenSSH)**:  
  Poly1305 derives its one-time key using the implicit 32-bit transport packet sequence number. Because RFC 4253 does not reset sequence numbers at `NEWKEYS`, active MitM sequence desynchronization allows undetected prefix truncation if strict KEX is bypassed.
* **Apple Silicon Hardware Acceleration**:  
  On Apple Silicon M-series CPUs, AES-GCM is executed by hardware cryptographic units (`ARMv8.5-A` instructions `AESD`, `AESE`, `PMULL`), achieving ~4x higher throughput and minimal CPU overhead compared to software-bound ChaCha20-Poly1305.

---

## 3. Host Key & Digital Signature Algorithms

```ssh
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com,sk-ssh-ed25519@openssh.com,sk-ssh-ed25519-cert-v01@openssh.com,ssh-mldsa44-ed25519@openssh.com,ssh-mldsa44-ed25519-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ecdsa-sha2-nistp256@openssh.com,sk-ecdsa-sha2-nistp256-cert-v01@openssh.com,rsa-sha2-512,rsa-sha2-256
```

1. **`ssh-ed25519` & certificates (RFC 8709)**: EdDSA over Curve25519. Primary host key standard.
2. **`sk-ssh-ed25519@openssh.com`**: FIDO2 / U2F hardware security keys with physical user presence.
3. **`ssh-mldsa44-ed25519@openssh.com` (NIST FIPS 204 ML-DSA)**:  
   Post-quantum hybrid digital signatures (ML-DSA-44 + Ed25519). Supported in OpenSSH 10.4+. Requires explicit declaration in `HostKeyAlgorithms` and `PubkeyAcceptedAlgorithms`.
4. **`rsa-sha2-512` & `rsa-sha2-256` (RFC 8332)**: SHA-2 RSA signatures for legacy compatibility. Legacy SHA-1 (`ssh-rsa`) is completely excluded.

---

## 4. Cryptographic Guardrails & Weakness Prevention

```ssh
WarnWeakCrypto yes
RequiredRSASize 4096
UpdateHostKeys ask
CASignatureAlgorithms ssh-ed25519,sk-ssh-ed25519@openssh.com,rsa-sha2-512,rsa-sha2-256
```

1. **`WarnWeakCrypto yes` (OpenSSH 10.1+ / NIST SP 800-131A)**:  
   Monitors algorithm negotiation during transport initialization. If an endpoint does not support post-quantum key exchange (falling back to classical DH or ECDH) or uses weakened ciphers, OpenSSH emits an immediate interactive warning to highlight Store-Now-Decrypt-Later (SNDL) exposure.
2. **`RequiredRSASize 4096` (RFC 8332 / Mozilla Hardened Standard / Zero-Legacy Security)**:  
   Hardware and algorithmic guardrail enforcing a minimum 4096-bit modulus for RSA signatures. Rejects all legacy 1024, 2048, and 3072-bit RSA keys during handshake, ensuring maximum classical factorization resistance if RSA fallback is ever encountered.
3. **`UpdateHostKeys ask` (RFC 8332 / OpenSSH HostKeyUpdate Protocol)**:  
   Allows servers to announce rotated host keys over an authenticated channel. Prompting (`ask`) verifies trust before writing changes to `known_hosts`.
4. **`CASignatureAlgorithms` (RFC 4253 / RFC 8332)**:  
   Enforces modern Ed25519, FIDO2, and SHA-2 RSA algorithms for Certificate Authority (CA) validation. Completely blocks legacy SHA-1 signatures issued by CAs.

---

## 5. Normative Standards & RFC Taxonomy

| Standard | Title | Application in Architecture |
| :--- | :--- | :--- |
| **RFC 4251** | The Secure Shell (SSH) Protocol Architecture | Architecture, protocol layering & threat model |
| **RFC 4252** | The Secure Shell (SSH) Authentication Protocol | Public key gating, agent isolation |
| **RFC 4253** | The Secure Shell (SSH) Transport Layer Protocol | Transport encryption, KEX, key renegotiation |
| **RFC 4254** | The Secure Shell (SSH) Connection Protocol | Channel timeouts, fail-closed port forwarding |
| **RFC 4255** | Using DNS to Securely Publish SSH Key Fingerprints | SSHFP host validation via DNSSEC (`VerifyHostKeyDNS`) |
| **RFC 5647** | AES-GCM Cipher Suites for Secure Shell (SSH) | Invocation counter reset ($IV=0$) Terrapin immunity |
| **RFC 8332** | Use of RSA Keys with SHA-256 and SHA-512 in SSH | Deprecation of SHA-1, `RequiredRSASize >= 2048` |
| **RFC 8709** | Ed25519 and Ed448 Public Key Algorithms for SSH | Primary digital signatures (`ssh-ed25519`) |
| **RFC 8731** | Secure Shell (SSH) Key Exchange Method using Curve25519 | Classical ECDH fallback (`curve25519-sha256`) |
| **NIST FIPS 203** | Module-Lattice-Based Key-Establishment (ML-KEM) | Primary hybrid PQC KEX (`mlkem768x25519-sha256`) |
| **NIST FIPS 204** | Module-Lattice-Based Digital Signature Standard (ML-DSA) | Composite PQ host/user signatures (`mldsa44-ed25519`) |
| **NIST SP 800-131A** | Transitioning Cryptographic Algorithms and Key Lengths | Mandatory retirement of sub-2048 bit RSA & SHA-1 |
