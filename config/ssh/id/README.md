# SSH Identities Subsystem (`~/.ssh/identities/`)

## Purpose
This directory houses static, public cryptographic identities (`.pub`) decoupled from root `~/.ssh/` to prevent Flat Namespace Smear and session hijacking vulnerabilities.

## Invariant
- **NEVER STORE PRIVATE KEYS HERE.**
- Private keys reside strictly in hardware silicon (Apple Secure Enclave Processor via Secretive, or FIDO2 YubiKey).
- Only `.pub` public keys belong in this directory.

## File Naming Standard
```text
~/.ssh/identities/<name>_<keytype>@<provider>.pub
```
Example:
`~/.ssh/identities/id_ecdsa-sha2-nistp256@github.pub`

## How to Export & Copy Your Public Key

### Option A: From Apple Secure Enclave (Secretive) via CLI
```bash
ssh-add -L | grep ecdsa-sha2-nistp256 > ~/.ssh/identities/id_ecdsa-sha2-nistp256@github.pub
```

### Option B: From Secretive GUI
1. Open **Secretive.app**.
2. Select your signing / auth key.
3. Click **"Copy Public Key"**.
4. Paste into `~/.ssh/identities/<name>_<keytype>@<provider>.pub`.

### Option C: From FIDO2 / YubiKey Hardware Token
```bash
ssh-keygen -K
mv id_ecdsa_sk.pub ~/.ssh/identities/id_sk-ecdsa@github.pub
```

## Permissions
```bash
chmod 0700 ~/.ssh/identities
chmod 0600 ~/.ssh/identities/*.pub
```
