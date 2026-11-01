# SOPS Dual-Recipient Disaster Recovery Runbook
### Platform : macOS Sequoia (Apple Silicon arm64 Darwin 25+)
### Standards: NIST SP 800-57 Pt. 1 Rev. 5 | SOPS Key-Wrapping Protocol
### Path     : `~/.ssh/docs/runbooks/sops-disaster-recovery.md`

---

## 1. Scope & Operational Objectives

This runbook defines standard operating procedures (SOP) for managing secrets encrypted with **SOPS** under the **Dual-Recipient (Secure Enclave + Cold Disaster Recovery)** architecture.

* **Primary Key**: Hardware-rooted Apple Secure Enclave (`age-plugin-se`), gated by Touch ID / Biometrics.
* **Recovery Key**: Cold master key (`age`), stored encrypted off-device for break-glass scenarios.

---

## 2. Standard Operating Procedures (Normal Operation)

### 2.1 Editing Encrypted Secrets
SOPS automatically selects the Secure Enclave identity handle from `~/.config/sops/age/keys.txt`, invokes `age-plugin-se`, and prompts for Touch ID:
```bash
sops secrets/bastion.enc.yaml
```

### 2.2 In-Memory Decryption to ssh-agent
For repository-scoped deploy keys or CI workflows, decryption occurs directly in RAM; plaintext private keys **never** touch disk:
```bash
sops decrypt secrets/id_ed25519_deploy.enc | ssh-add -
```

### 2.3 Adding or Encrypting New Secret Files
Ensure the file matches the regex specified in `~/.config/sops/.sops.yaml` (e.g. `*.enc.yaml`, `*secrets*`):
```bash
sops --encrypt --in-place secrets/api_keys.enc.yaml
```
SOPS encrypts the 256-bit data key to both recipients automatically.

---

## 3. Disaster Recovery Procedures (Break-Glass Scenarios)

### Scenario A: Local Mac Hardware Failure / Motherboard Replacement
When the primary MacBook is destroyed, lost, or repaired with a new logic board, the original Secure Enclave key is permanently inaccessible.

**Step 1: Retrieve Cold Recovery Key from Vault**
Access your cold escrow storage (e.g., 1Password Emergency Kit, physical offline vault).
Export the recovery private key:
```bash
export SOPS_AGE_KEY="AGE-SECRET-KEY-1..."
# OR if encrypted with age -p:
age --decrypt recovery_key.age > /tmp/recovery_key.txt
export SOPS_AGE_KEY_FILE="/tmp/recovery_key.txt"
```

**Step 2: Generate New Secure Enclave Identity on New Machine**
On the new Apple Silicon Mac:
```bash
age-plugin-se keygen --access-control=any-biometry-or-passcode --recipient-type=tag -o ~/.config/sops/age/keys.txt
```
Note the new public recipient: `age1tag1new...`.

**Step 3: Update `.sops.yaml` Configuration**
Replace the old Secure Enclave recipient in `~/.config/sops/.sops.yaml` with `age1tag1new...`, keeping the Recovery Recipient intact.

**Step 4: Re-wrap Repositories via Key Rotation Ceremony**
Using the Recovery Key active in the environment, re-encrypt all existing secret files:
```bash
sops updatekeys secrets/*.enc.yaml
```
*Verification*: Both the new Secure Enclave key and the Cold Recovery key are now authoritative.

**Step 5: Secure Wipe of Temporary Recovery Key**
```bash
unset SOPS_AGE_KEY
rm -P -f /tmp/recovery_key.txt  # Secure DoD 5220.22-M overwrite
```

---

### Scenario B: Fingerprint Tampering / Invalidation (`current-biometry`)
If the Secure Enclave key was generated with `--access-control=current-biometry` and a new fingerprint is enrolled in macOS:
1. `age-plugin-se` refuses to unlock secrets to prevent unauthorized insider access.
2. *Remedy*: Remove the newly added fingerprint in `System Settings -> Touch ID & Password` to restore enclave access, OR execute the Break-Glass recovery procedure above.

---

## 4. Key Rotation Audit Checklist

- [ ] `.sops.yaml` contains both Primary (SE) and Recovery (Cold) recipients.
- [ ] No unencrypted private keys exist in `~/.config/sops/age/keys.txt` (only `AGE-PLUGIN-SE-1...` handle).
- [ ] Recovery Key is stored outside the local filesystem in an encrypted, air-gapped medium.
- [ ] In-memory decryption passes runtime verification: `sops decrypt test.enc.yaml`.
- [ ] Git tracking ignores all unencrypted artifacts (`.gitignore`).
