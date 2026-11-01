# Secret Management Hardware Parity & Dual-Recipient Architecture
### Path: `~/.ssh/docs/security/secret-management-parity.md`
### Standards: NIST SP 800-57 Pt. 1 Rev. 5 | RFC 5647 | Age Encryption Specification

---

## 1. Architectural Asymmetry Analysis

Modern developer environments frequently combine multiple cryptographic sub-systems. An audit of this workstation revealed an asymmetric security boundary between the transport layer and the secret management layer:

```
SECURITY BOUNDARY ASYMMETRY
┌────────────────────────────────────────┐       ┌────────────────────────────────────────┐
│           SSH TRANSPORT TIER           │       │          SECRETS & SOPS TIER           │
│  Apple Silicon Secure Enclave (SEP)    │       │         Software age File on SSD       │
├────────────────────────────────────────┤       ├────────────────────────────────────────┤
│ • Private key never leaves silicon.    │       │ • Private key in plaintext on disk:    │
│ • Root/Kernel cannot dump key memory.  │       │   ~/.config/sops/age/keys.txt          │
│ • Hardware Touch ID prompt on every    │       │ • Any userland process or infostealer  │
│   signature challenge.                 │       │   can read and exfiltrate the key.     │
└────────────────────────────────────────┘       └────────────────────────────────────────┘
```

---

## 2. Hardware Remediation via `age-plugin-se`

To achieve true hardware-rooted parity across both SSH and secrets management, the `age` toolchain is bridged to the Apple Secure Enclave Processor using **`age-plugin-se`**.

### 2.1 The Non-Exportability Paradox & Dual-Recipient Requirement
Because Apple Secure Enclave private keys are physically bound to local silicon and non-exportable:
* A standalone migration to `age-plugin-se` creates an unacceptable **Disaster Recovery risk**: logic board replacement or laptop damage results in total loss of secrets.
* **Architecture Mandate**: All SOPS configuration rules must enforce **Dual-Recipient Encryption**:
  1. **Primary Recipient**: Apple Secure Enclave hardware key (`age-plugin-se`, Touch ID gated).
  2. **Recovery Recipient**: Air-gapped cold storage master key (`age` X25519) for break-glass recovery.

---

## 3. Cryptographic Implementation Details

### 3.1 Primary Hardware Key
* **Command**:
  ```bash
  age-plugin-se keygen --access-control=any-biometry-or-passcode --recipient-type=tag -o ~/.config/sops/age/keys.txt
  ```
* **Recipient Type `tag`**: Uses standardized `age1tag1...` encapsulation natively supported by `age` v1.3.0+ and SOPS. Enables non-macOS/CI environments to encrypt data without installing `age-plugin-se`.
* **Identity Handle**: The token `AGE-PLUGIN-SE-1...` is safe to reside in `~/.config/sops/age/keys.txt` because it is an opaque hardware pointer, inert on any other machine.

### 3.2 Cold Disaster Recovery Key
* **Command**:
  ```bash
  age-keygen -o /tmp/recovery_identity.txt
  age -p -o /tmp/recovery_vault.age /tmp/recovery_identity.txt
  ```
* Stored strictly outside the local machine (e.g. 1Password Emergency Kit, physical safe).

---

## 4. Declarative SOPS Blueprint (`~/.config/sops/.sops.yaml`)

```yaml
creation_rules:
  - path_regex: '.*(\.enc(\.|$)|secrets|vault|credentials).*'
    key_groups:
      - age:
          - '<PRIMARY_SE_RECIPIENT_TAG>'
          - '<COLD_RECOVERY_RECIPIENT>'
    encrypted_regex: '^(data|stringData|secrets|password|token|api_key|private_key|apiKey|secret.*)$'
```

---

## 5. In-Memory Decryption Pipeline

Operational SSH identities are strictly rooted in hardware silicon via Secretive (Touch ID SEP), eliminating plaintext private key files from disk. For external repository deploy keys or infrastructure secrets managed under SOPS, decryption occurs strictly in volatile RAM without touching persistent NVMe storage:

```bash
# In-memory injection of repository deploy keys directly into ssh-agent:
sops decrypt <repo>/secrets/id_ed25519_deploy.enc | ssh-add -
```

Both SSH hardware identities and SOPS master encryption keys achieve full biometric gating with zero unencrypted secrets on disk and guaranteed Disaster Recovery survivability.
