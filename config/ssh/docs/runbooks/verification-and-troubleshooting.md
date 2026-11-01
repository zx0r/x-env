# Operational Runbook: Verification & Troubleshooting
### Path: `~/.ssh/docs/runbooks/verification-and-troubleshooting.md`

---

## 1. Automated Verification Suite

Run these commands to verify that configuration directives are applied correctly:

### 1.1 Verify Modular Include Evaluation & Option Resolution
```bash
ssh -G github.com | grep -E "hostname|port|ciphers|kexalgorithms|obscurekeystroketiming|rekeylimit|channeltimeout"
```
*Expected Output*:
* `ciphers aes256-gcm@openssh.com,...`
* `kexalgorithms mlkem768x25519-sha256,...`
* `obscurekeystroketiming yes`
* `rekeylimit 1073741824 3600`
* `channeltimeout session=15m direct-tcpip=30m`

### 1.2 Verify Host Override Precedence
```bash
ssh -G openwrt | grep -E "hostname|stricthostkeychecking"
```
*Expected Output*:
* `hostname openwrt.lan`
* `stricthostkeychecking accept-new` (Confirms `20-hosts.conf` beat `90-security.conf`).

### 1.3 Verify Hardware Secure Enclave Socket
```bash
SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock ssh-add -l
```
*Expected Output*:
* Displays ECDSA P-256 public key fingerprint managed by Secretive.

### 1.4 Test Live GitHub Authentication
```bash
ssh -T -o "BatchMode=yes" git@github.com
```
*Expected Output*:
* Displays ASCII randomart image (`VisualHostKey yes`).
* Outputs: `Hi zx0r! You've successfully authenticated...`.

### 1.5 OpenSSH Client Configuration Validator (CIS & NIST Controls)
Audit OpenSSH client configuration against CIS OpenSSH Benchmark (v1.0.0) and NIST SP 800-53 Rev. 5 controls (45 checks):
```bash
~/.local/bin/ssh/validate
# Machine-readable JSON output:
~/.local/bin/ssh/validate --json | jq .
```
*Controls evaluated*: File system permissions (CIS 5.2.1), private key storage at rest (NIST SC-28), configuration syntax, post-quantum key exchange (NIST FIPS 203 / FIPS 204), symmetric ciphers and MACs (CIS 5.2.10 - 5.2.12, RFC 5647), channel forwarding restrictions (CIS 5.2.4 - 5.2.7), authentication and hardware key storage (CIS 5.2.8, NIST IA-2), host verification (CIS 5.2.2, CIS 5.2.3), and commit signature verification (NIST SI-7).

### 1.6 Cryptography & OpenSSH Client Validator
Audit age key storage and OpenSSH client configuration in a single pass:
```bash
~/.local/bin/age/validate
# Execution modes:
~/.local/bin/age/validate --age-only  # age X25519 & SOPS key store only
~/.local/bin/age/validate --ssh-only  # OpenSSH CIS/NIST checks only
~/.local/bin/age/validate --json      # Unified JSON report
```

---

## 2. Troubleshooting & Recovery Procedures

### 2.1 Stale ControlMaster Sockets (`Connection refused`)
* **Symptom**: `ssh` hangs or fails with `Control socket connect(...): Connection refused` after laptop sleep or Wi-Fi network transition.
* **Remediation**:
  Purge dead multiplexing socket descriptors:
  ```bash
  rm -f ~/.ssh/cm-*
  ```

### 2.2 Inbound SSH Deadlock (No Touch ID GUI)
* **Symptom**: Connecting into the Mac remotely over SSH causes Git or SSH commands to hang indefinitely.
* **Root Cause**: Secretive attempts to trigger a GUI Touch ID challenge on the physical Mac trackpad, which is unreachable from a remote terminal.
* **Resolution**: The `11-identity-agent.fish` script automatically checks `SSH_CLIENT` / `SSH_CONNECTION` and preserves forwarded agent sockets during inbound SSH sessions.

### 2.3 Resetting Unresponsive Secretive Agent
If Secretive stops responding to signature requests:
```bash
killall Secretive SecretAgent 2>/dev/null || true
open -a Secretive
SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock ssh-add -l
```

### 2.4 Git Commit Signing Verification
Verify that commits are cryptographically verified via `PROTOCOL.sshsig`:
```bash
git log --show-signature -1
```
*Expected Output*:
* `Good "git" signature for 117382621+zx0r@users.noreply.github.com with ECDSA key...`
