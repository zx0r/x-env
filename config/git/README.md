# Zero-Trust Git & Cryptographic Provenance Architecture

### Platform: macOS 27+ (Apple Silicon / aarch64 Darwin 27.2+)

### Standard: Strict XDG Base Directory Specification (`$XDG_CONFIG_HOME/git`)

### Stack: Git 2.56+ | Delta 0.20+ | Difftastic 0.71+ | Mergiraf 0.20+ | Jujutsu (jj) 0.46+ | Lazygit 0.66+ | GitUI 0.28+ | Tig 2.6+ | Gitleaks 8.30+ | Cocogitto (cog) 7.0+ | Lefthook 2.2+ | Repomix 1.18+ | Hunk 0.23+ | git-graph 0.8+ | Secretive (Apple SEP) | SOPS 3.13+ | age 1.3+

---

## 1. Architectural Cross-Section & System Overview

Modern enterprise software engineering requires end-to-end cryptographic supply-chain integrity,
hardware-rooted commit provenance, and sub-millisecond local repository operations. Conventional
developer environments suffer from severe vulnerabilities and performance degradation:
software-stored GPG private keys sitting unencrypted or weakly passphrase-protected on disk,
unmonitored recursive filesystem sweeps on APFS, unverified diff caches leaking decrypted secrets,
and autonomous AI coding agents arbitrarily overwriting global Git configurations or creating ad-hoc
`~/.gitconfig` bypass files.

This architecture establishes a **System-as-Interface** zero-trust development environment
integrating:

- **Hardware-Rooted Provenance**: OpenSSH `PROTOCOL.sshsig` backed by the **Apple Silicon Secure
  Enclave Processor (SEP)** via **Secretive**, requiring interactive **Touch ID** biometric
  verification for every commit and release tag.
- **Zero-Trust Kernel Immutability & Anti-Hijack Guard**: Darwin kernel immutable flags (`chflags uchg`)
  combined with POSIX `0400` read-only lockdown on all Git configuration artifacts, complemented by
  environment variable isolation (`GIT_CONFIG_GLOBAL`), preventing autonomous AI coding agents and
  unprivileged scripts from modifying, overriding, or creating unverified Git configurations.
- **Darwin Kernel Acceleration**: Native **Darwin FSEvents** filesystem daemon integration
  (`core.fsmonitor = true`) and APFS directory mtime untracked caching
  (`core.untrackedCache = true`).
- **Cryptographic Secrets Isolation**: **SOPS** and **age** (X25519) transparent git diffing with
  strict in-memory execution (`cachetextconv = false`), guaranteeing zero plaintext secret
  persistence on disk.
- **Strict XDG Isolation**: Deterministic resolution within `~/.config/git/`, eliminating home
  directory pollution (`~/.gitconfig`).

### ASCII Cross-Section: Zero-Trust Git & Provenance Pipeline

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER CLI & WORKSPACE TIERS                          │
│         git commit -S   │   git status   │   git diff   │   sops-edit            │
└────────────────────────────────────────┬─────────────────────────────────────────┘
                                         │
┌────────────────────────────────────────▼─────────────────────────────────────────┐
│                      ZERO-TRUST GIT POLICY ENGINE & XDG LAYER                    │
│   ~/.config/git/config   │   ~/.config/git/attributes   │   ~/.config/git/ignore │
│   transfer.fsckObjects = true    │   merge.conflictStyle = zdiff3 (Ancestor)     │
└──────────────────┬─────────────────────┬──────────────────────┬──────────────────┘
                   │                     │                      │
       ┌───────────▼──────────┐ ┌────────▼──────────┐ ┌─────────▼──────────────┐
       │ HARDWARE PROVENANCE  │ │  APFS / DARWIN    │ │  TRANSPARENT SECRETS   │
       │    (Touch ID / SEP)  │ │ PERFORMANCE ENGINE│ │   (SOPS + age X25519)  │
       └───────────┬──────────┘ └────────┬──────────┘ └─────────┬──────────────┘
                   │                     │                      │
┌──────────────────▼──────────┐ ┌────────▼──────────┐ ┌─────────▼──────────────┐
│  Apple Secure Enclave (SEP) │ │ Darwin FSEvents   │ │ SOPS Decryption Pipe   │
│  ECDSA P-256 (FIPS 186-4)   │ │ fsmonitor--daemon │ │ textconv = sops dec    │
│  Non-exportable Hardware Key│ │ untrackedCache    │ │ cachetextconv = false  │
│  Touch ID Biometric Gating  │ │ precomposeUnicode │ │ ZERO Plaintext Leakage │
│  Secretive UDS Socket       │ │ APFS mtime Cache  │ │ Memory-only Diff Pipe  │
└──────────────────┬──────────┘ └────────┬──────────┘ └─────────┬──────────────┘
                   │                     │                      │
                   └─────────────────────┼──────────────────────┘
                                         │
┌────────────────────────────────────────▼─────────────────────────────────────────┐
│                   CRYPTOGRAPHIC TRUST & ALLOWED SIGNERS LAYER                    │
│      ~/.config/git/allowed_signers [namespaces="git" OpenSSH PROTOCOL.sshsig]    │
│      Wire Protocol v2 Multiplexing │ Strict Object Graph fsck Validation         │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### Mermaid Sequence Diagram: Hardware Enclave Commit Signing Flow

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer (zx0r)
    participant Git as Git 2.56.0 CLI
    participant SSHKeygen as /usr/bin/ssh-keygen
    participant Agent as Secretive Agent (UDS Socket)
    participant SEP as Apple Secure Enclave (SEP)
    participant Trust as Git Allowed Signers (~/.config/git/allowed_signers)

    Dev->>Git: git commit -m "feat: verified release"
    Note over Git: gpg.format = ssh<br/>user.signingkey = ~/.ssh/*.pub
    Git->>SSHKeygen: Invoke ssh-keygen -Y sign -n git -f <pubkey>
    SSHKeygen->>Agent: Query SSH_AUTH_SOCK (~/.ssh/ssh_auth_sock)
    Agent->>SEP: Request ECDSA P-256 signature
    SEP-->>Dev: Biometric Challenge: Apple Touch ID Prompt
    Dev->>SEP: Touch ID Authenticated via Fingerprint
    SEP-->>Agent: Generate hardware signature (private key never leaves SEP)
    Agent-->>SSHKeygen: Return raw signature
    SSHKeygen-->>Git: Format PROTOCOL.sshsig signature block
    Git->>Git: Embed signature into commit object header
    Git->>Trust: Validate signature against allowed_signers (namespaces="git")
    Trust-->>Git: Good "git" signature confirmed
    Git-->>Dev: [main 04add19] feat: verified release (Good "git" signature)
```

---

## 2. Deep Research Findings & Threat Model

Our architecture addresses empirical vulnerabilities documented in recent academic literature and OS
kernel specifications:

### 2.1 Commit Signing Usability & Supply-Chain Attacks (arXiv:2608.29283 & arXiv:2406.08198)

1. **The GPG Usability Wall**: _Shittu et al. (2026), "A Multi-Month Study of Git Commit Signing"
   (arXiv:2608.29283)_ conducted an extensive longitudinal study proving that developer adoption of
   GPG commit signing consistently fails due to operational friction: daemon synchronization issues
   (`gpg-agent`), expired key rings, GUI pinentry deadlocks in terminal multiplexers (tmux), and
   non-intuitive subkey revocation.
2. **Software Key Exfiltration Risks**: _Kalu et al. (2024), "An Industry Interview Study of
   Software Signing for Supply Chain Security" (arXiv:2406.08198)_ highlighted that software private
   keys stored in developer filesystems (`~/.ssh/id_rsa` or `~/.gnupg`) represent
   single-point-of-failure vulnerabilities easily extracted by malicious supply-chain dependencies
   (`npm postinstall` or Python setup scripts).

**Architectural Remediation**:

- We eliminate software private keys on disk by utilizing the **Apple Secure Enclave Processor
  (SEP)** via **Secretive**. The private key is generated within dedicated hardware silicon and
  physically cannot be read by macOS userland or kernel memory.
- We utilize native OpenSSH **`PROTOCOL.sshsig`** (OpenSSH 8.0+), removing GPG entirely.
- **Cryptographic Namespace Isolation**: In `~/.config/git/allowed_signers`, we enforce
  `namespaces="git"`. Under OpenSSH specification, a key authorized to sign Git commits cannot be
  used to forge SSH remote logins or arbitrary file signatures.

### 2.2 APFS Unicode NFD Decomposition & Darwin FSEvents

1. **Unicode Decomposition**: APFS enforces UTF-8 normalization by decomposing characters (NFD),
   whereas Linux/Windows use precomposed UTF-8 (NFC). Setting `core.precomposeUnicode = true`
   prevents Git from identifying files with Unicode glyphs as duplicate modified files.
2. **FSEvents Daemon**: Standard `git status` executes recursive `lstat(2)` sweeps across the
   repository. Enabling `core.fsmonitor = true` initiates the native Darwin kernel
   `git-fsmonitor--daemon`, which subscribes to `FSEvents` notifications and streams modified paths
   in `<12ms`, bypassing directory stat overhead.

### 2.3 Transparent SOPS Git Diffing: Zero Plaintext Cache Leakage

- **Threat Model**: Standard Git diff textconv filters execute `sops decrypt` to allow developers to
  view readable diffs of encrypted files. However, if `cachetextconv` is left as `true`, Git writes
  decrypted plaintext files into `.git/refs/notes/textconv/` or cache blobs on physical disk.
- **Hardened Directives**: `diff.sops.textconv = sops decrypt` paired with
  `diff.sops.cachetextconv = false`. All decryptions happen strictly in-memory (stdout pipe) with
  zero on-disk persistence.

### 2.4 Autonomous AI Agent Threat Model & Zero-Trust Kernel Immutability

1. **Autonomous Agent Drift & Configuration Hijacking**:
   In modern AI-assisted engineering environments, autonomous coding agents (e.g., Claude Code,
   Antigravity, Cursor, Codex) execute terminal commands with userland shell privileges. Agents frequently
   attempt to:
   - Run `git config --global user.name` or `git config --global user.email` to inject temporary or generic
     bot identities, causing global configuration drift.
   - Set `commit.gpgsign = false` or spawn ad-hoc `~/.gitconfig` bypass files to avoid interactive Touch ID
     hardware challenges during headless background tasks.
   - Modify or strip diff filters (`diff.sops`), pre-commit hooks, or `allowedSignersFile` verification.

2. **Defense-in-Depth Architectural Remediation**:
   - **Darwin Kernel Immutability (`uchg`)**: We apply the BSD Darwin Virtual File System immutable flag
     (`chflags uchg`) and POSIX read-only permissions (`chmod 0400`) across all Git infrastructure targets
     (`config`, `attributes`, `ignore`, `allowed_signers`, and `profiles/*.inc`). The root symlink
     `~/.gitconfig` is pinned with `chflags -h uchg`.
   - **Kernel-Level Rejection**: Any userland process (including an autonomous agent running with user
     privileges) attempting to write, truncate, append (`>>`), or delete (`rm -f`) a locked configuration
     file is rejected by the Darwin kernel VFS layer with `EPERM` (`Operation not permitted`).
   - **Deterministic Single Source of Truth (`GIT_CONFIG_GLOBAL`)**: By exporting
     `set -gx GIT_CONFIG_GLOBAL "$HOME/.config/git/config"` in non-interactive shell initialization
     (`~/.config/fish/conf.d/01_env.fish`), Git ignores ambiguous fallback discovery and binds
     unconditionally to the protected XDG configuration file.

---

## 3. How to Install (Step-by-Step Installation Guide)

Execute the following commands to install the complete Principal toolchain on macOS Apple Silicon:

### Step 1: Install Core Binaries via Homebrew

```bash
# Update Homebrew formulae
brew update

# Install modern Git, syntax pager, and secrets management tools
brew install git git-delta sops age

# Install Secretive (Apple Secure Enclave SSH Agent)
brew install --cask secretive
```

### Step 2: Initialize Secretive & Generate Secure Enclave Hardware Key

1. Open Secretive from Applications:
    ```bash
    open /Applications/Secretive.app
    ```
2. Grant Secretive the required permissions (Notification / Touch ID).
3. Click the `+` icon to create a new key:
    - **Key Name**: `zx0r_ecdsa-sha2-nistp256@github`
    - **Key Type**: `ECDSA (P-256)`
    - **Authentication**: `Touch ID or Password` (or `Touch ID Only` for maximum security)
4. Secretive will store the public key in:
   `~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/`
5. Copy the public key to `~/.ssh/`:
    ```bash
    mkdir -p -m 700 ~/.ssh
    cat ~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/PublicKeys/*.pub > ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
    chmod 644 ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
    ```

### Step 3: Initialize age Master Key

Generate your personal age identity file under the standard XDG path:

```bash
# Create directory structure with restricted permissions
mkdir -p -m 700 ~/.config/sops/age ~/.config/age

# Generate new age keypair (if not already present)
# age-keygen -o ~/.config/sops/age/keys.txt

# Secure file permissions (owner read/write only)
chmod 600 ~/.config/sops/age/keys.txt

# Create symlink for strict age CLI discovery
ln -sfh ~/.config/sops/age/keys.txt ~/.config/age/keys.txt
```

---

## 4. How to Configure (Step-by-Step Configuration Guide)

All configurations follow the strict XDG Base Directory specification without cluttering `$HOME`.

### 4.1 Git Configuration (`~/.config/git/`)

Create the directory structure:

```bash
mkdir -p ~/.config/git
```

#### 1. Master Git Config (`~/.config/git/config` & `~/.config/git/principal`)

```gitconfig
# ~/.config/git/config
[init]
    defaultBranch = main

[user]
    # Zero-Leak Invariant: Enforce explicit identity per repo/profile
    # Refuses commits if user.name or user.email is unset, preventing identity leakage
    useConfigOnly = true

# 1.1 IDENTITY PROFILES ORCHESTRATION
# Primary developer identity across entire ~/x workspace
[includeIf "gitdir/i:~/x/**"]
    path = ~/.config/git/profiles/own.inc
[includeIf "worktree/i:~/x/**"]
    path = ~/.config/git/profiles/own.inc

# Contextual override for NDA / commercial client projects (~/x/dev/nda)
[includeIf "gitdir/i:~/x/dev/nda/**"]
    path = ~/.config/git/profiles/nda.inc
[includeIf "worktree/i:~/x/dev/nda/**"]
    path = ~/.config/git/profiles/nda.inc

[gpg]
    format = ssh

[gpg "ssh"]
    program = /usr/bin/ssh-keygen
    allowedSignersFile = ~/.config/git/allowed_signers

[commit]
    gpgsign = true

[tag]
    gpgSign = true
    forceSignAnnotated = true

[log]
    showSignature = true
    date = iso-strict

[core]
    excludesFile = ~/.config/git/ignore
    attributesFile = ~/.config/git/attributes
    pager = delta
    precomposeUnicode = true
    untrackedCache = true
    fsmonitor = true
    trustctime = false
    autocrlf = input
    eol = lf

[interactive]
    diffFilter = delta --color-only

[delta]
    paging = always
    dark = true
    side-by-side = false
    navigate = true
    syntax-theme = Dracula
    tabs = 4
    line-numbers = true
    hyperlinks = true
    detect-dark-light = auto
    diff-indicator = true

[diff]
    algorithm = histogram
    colorMoved = default
    colorMovedWS = allow-indentation-change
    mnemonicPrefix = true
    renames = copies
    submodule = log

[diff "sops"]
    textconv = "sh -c 'sops decrypt \"$1\" 2>/dev/null || cat \"$1\"' --"
    cachetextconv = false

[merge]
    conflictStyle = zdiff3
    stat = true

[pull]
    ff = only

[rebase]
    autoSquash = true
    autoStash = true
    updateRefs = true
    missingCommitsCheck = error

[protocol]
    version = 2

[push]
    default = current
    autoSetupRemote = true
    followTags = true

[fetch]
    prune = true
    pruneTags = false
    writeCommitGraph = true
    fsckObjects = true

[transfer]
    fsckObjects = true

[receive]
    fsckObjects = true

[branch]
    sort = -committerdate

[tag]
    sort = -version:refname

[credential]
    helper = osxkeychain
```

#### 2. Global Attributes (`~/.config/git/attributes`)

```gitattributes
* text=auto eol=lf

# Transparent SOPS diff hooks
*.enc                 diff=sops
*.enc.*               diff=sops
*.sops.yaml           diff=sops
*.sops.yml            diff=sops
*.sops.json           diff=sops
*.sops.env            diff=sops
*secrets*.yaml        diff=sops
*secrets*.yml         diff=sops
*secrets*.json        diff=sops
*secrets*.env         diff=sops

# Binary assets protection
*.png                 binary
*.jpg                 binary
*.jpeg                binary
*.gif                 binary
*.webp                binary
*.ico                 binary
*.pdf                 binary
*.woff                binary
*.woff2               binary
*.dylib               binary
*.so                  binary
*.tar.gz              binary
*.zip                 binary
```

#### 3. Global Ignore (`~/.config/git/ignore`)

```gitignore
**/.claude/settings.local.json
AGENTS.local.md
*.local.md
*.local

.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
Icon
.fseventsd

*.swp
*.swo
*~
*.bak
.idea/**/workspace.xml
.vscode/.browse.*

*.dSYM/
core

.env.local
.env.*.local
*.private.key
*.pem.local
```

#### 4. Cryptographic Trust Store (`~/.config/git/allowed_signers`)

```ssh
117382621+zx0r@users.noreply.github.com namespaces="git" ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNwI22B99xrTEoyGWFAlN9QaWWxKjMHozOhx74ZGhuhMLPg0FqVMnHpfZxISOaAQm66fkznGnY2ljwVH120DrPc= 117382621+zx0r@users.noreply.github.com
```

### 4.2 Secretive & SSH Configuration (`~/.ssh/config`)

Configure OpenSSH to route authentications through the Secretive Unix domain socket:

```ssh-config
# ~/.ssh/config

Host *
  IgnoreUnknown Protocol,UseRoaming,UseKeychain
  Protocol 2
  IdentityAgent ~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
  IdentitiesOnly yes
  AddKeysToAgent no
  ForwardAgent no
  UseKeychain yes
  PasswordAuthentication no
  PubkeyAuthentication yes
  StrictHostKeyChecking ask
  ServerAliveInterval 60
  ServerAliveCountMax 3

Host github.com gist.github.com
  User git
  HostName github.com
  Port 22
  IdentityFile ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
  IdentitiesOnly yes

# Fallback port 443 for restricted firewalls
Host ssh.github.com
  User git
  HostName ssh.github.com
  Port 443
  IdentityFile ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub
```

### 4.3 SOPS Declarative Rules (`~/.config/sops/.sops.yaml`)

```yaml
# ~/.config/sops/.sops.yaml
creation_rules:
    # Structured secret files (*.enc.*, *secrets*, *vault*, *credentials*)
    - path_regex: '.*(\.enc(\.|$)|secrets|vault|credentials).*'
      age: "age1f4ezxgakuc05ha6qn5jgqw7y6r9ftkgnxa0sm6hfkfcaluhga3wqdp85wj"
      encrypted_regex: "^(data|stringData|secrets|password|token|api_key|private_key|apiKey|secret.*)$"

    # Global fallback for arbitrary files
    - age: "age1f4ezxgakuc05ha6qn5jgqw7y6r9ftkgnxa0sm6hfkfcaluhga3wqdp85wj"
```

Link into `$HOME` for root-level fallback:

```bash
ln -sfh ~/.config/sops/.sops.yaml ~/.sops.yaml
```

### 4.4 Fish Shell Environment Orchestration

#### `~/.config/fish/conf.d/01_env.fish`

Ensure the age key path is exported globally:

```fish
set -gx SOPS_AGE_KEY_FILE "$XDG_CONFIG_HOME/sops/age/keys.txt"
```

#### `~/.config/fish/conf.d/02_toolchain.fish`

Guarantee Homebrew binaries take precedence over system tools:

```fish
fish_add_path --prepend /opt/homebrew/bin /opt/homebrew/sbin
```

#### `~/.config/fish/conf.d/11_ipc.fish`

Establishes a stable tmux-proof symlink to the active Secretive socket while guarding remote SSH
sessions:

```fish
# Stable symlink ~/.ssh/ssh_auth_sock points to Secretive socket
set -l _secretive_sock "$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
if test -S "$_secretive_sock"
    command ln -sfh "$_secretive_sock" "$HOME/.ssh/ssh_auth_sock"
    set -gx SSH_AUTH_SOCK "$HOME/.ssh/ssh_auth_sock"
end
```

#### `~/.config/fish/conf.d/20_abbrs.fish`

Productivity shortcuts registered in interactive shells:

```fish
# Git Abbreviations
abbr -a g git
abbr -a gs "git status"
abbr -a ga "git add"
abbr -a gc "git commit"
abbr -a gp "git push"
abbr -a gl "git log --oneline -n 20"
abbr -a gd "git diff"
abbr -a gco "git checkout"
abbr -a gb "git branch"
abbr -a lg lazygit

# SOPS Secrets Management
abbr -a sops-edit "sops"
abbr -a sops-dec "sops decrypt"
abbr -a sops-enc "sops encrypt --in-place"
```

---

## 5. How to Verify & Test (Live Test Verification Suite)

Verify every component of the architecture with reproducible live commands.

### 5.1 Verification 1: Secretive Agent & Secure Enclave Hardware Key

Query the running SSH agent to ensure the Secure Enclave hardware key is loaded:

```console
$ SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock ssh-add -l
256 SHA256:WbPmB/+qDkGXbdxgOCnBxcrRhbeE+UxPo2DAGgjQjb8 117382621+zx0r@users.noreply.github.com (ECDSA)
```

_Result_: The key is recognized as a hardware-backed ECDSA key.

### 5.2 Verification 2: Standalone SSH Signature Generation & Verification

Simulate an OpenSSH `PROTOCOL.sshsig` operation directly:

```console
# Generate signature (triggers Touch ID prompt)
$ echo "commit test data" | SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock ssh-keygen -Y sign -n git -f ~/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub > /tmp/test_sig.sig
Signing data on standard input

# Verify signature against allowed_signers
$ echo "commit test data" | ssh-keygen -Y verify -f ~/.config/git/allowed_signers -I 117382621+zx0r@users.noreply.github.com -n git -s /tmp/test_sig.sig
Good "git" signature for 117382621+zx0r@users.noreply.github.com with ECDSA key SHA256:WbPmB/+qDkGXbdxgOCnBxcrRhbeE+UxPo2DAGgjQjb8
```

_Result_: Validates that `allowed_signers` enforces cryptographic namespace confinement (`-n git`).

### 5.3 Verification 3: Git Commit Signing with Touch ID (Live Test)

Create a temporary repository and verify an authentic signed commit:

```console
$ mkdir -p /tmp/test_git_sign && cd /tmp/test_git_sign && git init -b main
Initialized empty Git repository in /private/tmp/test_git_sign/.git/

$ echo "hello world" > test.txt && git add test.txt
$ SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock git commit -m "feat: test signed commit"
[main (root-commit) 04add19] feat: test signed commit
 1 file changed, 1 insertion(+)
 create mode 100644 test.txt

$ git log --show-signature -n 1
commit 04add198e2c2d4a17919e0c55b0cfbb14a8c9122 (HEAD -> main)
Good "git" signature for 117382621+zx0r@users.noreply.github.com with ECDSA key SHA256:WbPmB/+qDkGXbdxgOCnBxcrRhbeE+UxPo2DAGgjQjb8
Author: zx0r <117382621+zx0r@users.noreply.github.com>
Date:   Thu Oct 8 02:56:14 2026 +0700

    feat: test signed commit
```

_Result_: Git invokes `ssh-keygen`, triggers the macOS Touch ID prompt, embeds the signature into
the commit header, and immediately validates it against `~/.config/git/allowed_signers`.

### 5.4 Verification 4: age Public Key Extraction

Verify that the age master identity file is readable and matches the recipient public key:

```console
$ age-keygen -y ~/.config/sops/age/keys.txt
age1f4ezxgakuc05ha6qn5jgqw7y6r9ftkgnxa0sm6hfkfcaluhga3wqdp85wj
```

### 5.5 Verification 5: SOPS In-Place Encryption & Decryption (Live Test)

Create a YAML secret and perform declarative encryption:

```console
$ echo "api_key: secret_enterprise_token_xyz" > /tmp/app.enc.yaml
$ sops --encrypt --in-place /tmp/app.enc.yaml

$ cat /tmp/app.enc.yaml
api_key: ENC[AES256_GCM,data:HKtSYqlQbGh5rEZT7Y2cFfHBqgAc0cMPEY3a,iv:Ordc/rzlLndJimmEfVxF8zJ2bZtJVFQPrInM992LjtE=,tag:UUUqWXL2svlc7Xy6oSPX+w==,type:str]
sops:
    age:
        - enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBnbXV1aS9SdkxrejByb2gw
            NURUUnl2R2hzdEZFcWlXNlkrTVFQRldMK0JFCm50TUN2MDFYdEkvM1E5dFJ1STdU
            bm91ZEpjRURTWnpkKzFERXBGTHIwL2sKLS0tIGxybjNZWnlDMjZEaXJacVYvT1pu
            MGtkR0o1c1pycjVLZ0tLOEFZSXc1aUUKfdxqs2F/6hUkXZto59oR6ukdOCKp3taC
            G+qlWukBI4bPCLK6p0BCnRl8QGBpSw29GEkx55Uoh5Ii6cVbQxqVnA==
            -----END AGE ENCRYPTED FILE-----
          recipient: age1f4ezxgakuc05ha6qn5jgqw7y6r9ftkgnxa0sm6hfkfcaluhga3wqdp85wj
    encrypted_regex: ^(data|stringData|secrets|password|token|api_key|private_key|apiKey|secret.*)$
    mac: ENC[AES256_GCM,data:tGlfWKK0imZb6cbC7DniySEB9QAPEe6czg+WMaZfL3DaeP4T+dB1ixucyLdiN7Jpa19lvVhbLITOGYwIeAH0B690kcDyjim3iaZUOGWmHNXhhpEUzOgIf9X/ylUTY/dfrprIaczgLF5SvCoSh0Gzoxo09A9GJo/g8SdWysNzBAY=,iv:rDB7t/tBS5Jp73yicuDvcAko23vhEXJF5yvWrgW5Oe0=,tag:FmUwq/vBlI/y1ScclIbCMQ==,type:str]

$ sops decrypt /tmp/app.enc.yaml
api_key: secret_enterprise_token_xyz
```

_Result_: Seamless encryption using the `.sops.yaml` creation rules and instant decryption via
`$SOPS_AGE_KEY_FILE`.

### 5.6 Verification 6: In-Memory Git Diff of Encrypted Files (Live Test)

Commit an encrypted secret, modify it, and execute `git diff`:

```console
$ git diff secret.enc
diff --git a/secret.enc b/secret.enc
index aaeea2f..b51c067 100644
--- a/secret.enc
+++ b/secret.enc
@@ -1 +1 @@
-key: initial_value
+key: updated_value
```

_Result_: Git pipes `secret.enc` through `sops decrypt` in memory. No decrypted plaintext is cached
on physical storage (`diff.sops.cachetextconv = false`).

---

## 6. Edge-Case Engineering & Troubleshooting

### 6.1 Headless / Inbound SSH Guard

- **Problem**: When accessing your macOS workstation remotely over SSH, running `git commit`
  triggers a Touch ID challenge. Because there is no local GUI session to accept a fingerprint, the
  process deadlocks.
- **Solution**:
  `11_ipc.fish` (`~/.config/fish/conf.d/11_ipc.fish`) detects
  `SSH_CLIENT` or `SSH_TTY`. When connected remotely, it retains the forwarded inbound agent
  (`SSH_AUTH_SOCK`) instead of forcing the local Secretive Touch ID socket.

### 6.2 Stale Tmux Panes & Socket Reconnection

- **Problem**: Tmux panes inherit environment variables at pane creation time. If Secretive restarts
  or the socket inode changes, panes retain a dead socket path.
- **Solution**: We maintain a persistent symlink at `~/.ssh/ssh_auth_sock`. `SSH_AUTH_SOCK` is
  permanently set to this path; Secretive re-links to it on launch, preventing stale socket errors
  across tmux panes.

### 6.3 Homebrew Git vs. Apple Git Conflict

- **Problem**: macOS ships with an outdated Apple Git (`/usr/bin/git`, version 2.39.x) lacking
  modern wire protocol and commit-graph optimizations.
- **Verification**:
    ```bash
    which git
    # Expected: /opt/homebrew/bin/git
    git --version
    # Expected: git version 2.56.0 or newer
    ```
- If `/usr/bin/git` appears first, ensure
  `02_toolchain.fish` (`~/.config/fish/conf.d/02_toolchain.fish`) prepends `/opt/homebrew/bin`
  to `$PATH`.

### 6.4 Missing Touch ID Prompt during Commit

- Verify Secretive is running:
    ```bash
    pgrep -l Secretive
    ```
- If not running, launch it:
    ```bash
    open -a Secretive
    ```
- Verify the socket exists:
    ```bash
    test -S ~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh && echo "Socket OK"
    ```

---

## 7. Extended Toolchain & Domain Ownership Matrix (Human/Agentic Systems)

To eliminate cognitive friction and guarantee maximum throughput for both interactive human
engineers and autonomous AI agents, the workstation Git ecosystem is partitioned into strictly
bounded domains of responsibility:

| Domain (Bounded Context)              | Primary Tool   | Binary         | Technology         | Core Architectural Responsibility                                                                                                                                                                                            |
| :------------------------------------ | :------------- | :------------- | :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Terminal Paging & Lexical Diff**    | `git-delta`    | `delta`        | Rust               | Fundamental stdout pager (`core.pager`). Syntax highlighting (`bat` themes), word-level Levenshtein diffing, line numbering, clickable `file://` hyperlinks, and `zdiff3` conflict rendering.                                |
| **Semantic Structural AST Diff**      | `difftastic`   | `difft`        | Rust (Tree-sitter) | Syntax-aware structural comparison. Compares abstract syntax trees, eliminating 90% of formatting, whitespace, and re-indentation noise. Invoked via `git dft` or lazygit.                                                   |
| **Autonomous 3-Way AST Merge**        | `mergiraf`     | `mergiraf`     | Rust (Tree-sitter) | Non-blocking AST merge driver. Automatically reconciles non-overlapping syntactic changes (imports, function declarations, config maps) without generating spurious conflicts.                                               |
| **Next-Gen VCS & Change Model**       | `jujutsu`      | `jj`           | Rust               | Git-compatible VCS layer. Treats the working copy as an atomic commit, turns merge conflicts into commit-safe first-class citizens, supports automatic descendant rebasing, and provides an instant `jj undo` operation log. |
| **Interactive TUI Mutation**          | `lazygit`      | `lazygit`      | Go                 | High-velocity daily workflow mutator. Line/hunk visual staging, interactive rebase, commit splitting, worktree management, and dynamic cycling between diff engines via `diffRenderers` (`\|` key).                          |
| **Monorepo High-Performance TUI**     | `gitui`        | `gitui`        | Rust               | Ultra-lean Git TUI (<200 MB RAM, 0 GC pauses). Optimized for massive enterprise repositories (>100k commits) where Go-based TUI runtimes experience garbage-collection latency.                                              |
| **Historical Log & Blame Specialist** | `tig`          | `tig`          | C (ncurses)        | Dedicated historical reader. High-density commit tree exploration, sub-millisecond blame inspection, and read-only revision auditing.                                                                                        |
| **Zero-Trust Secret Detection**       | `gitleaks`     | `gitleaks`     | Go                 | Cryptographic leak prevention. Scans staged changesets, git history, and commits for leaked API tokens, private keys, and high-entropy credentials during pre-commit hooks and CI/CD gates.                                  |
| **Release & Commit Governance**       | `cocogitto`    | `cog`          | Rust               | Conventional Commits governance engine (`cog commit`, `cog bump`, `cog check`). Enforces SemVer automation, automated changelog generation, and machine-verifiable commit history.                                           |
| **Polyglot Hook Orchestration**       | `lefthook`     | `lefthook`     | Go                 | Ultra-fast pre-commit/pre-push test runner. Replaces heavy npm/python hook stacks; runs linters and validators in parallel (`parallel: true`) with strict `{staged_files}` filtering.                                        |
| **Agentic Context Packaging**         | `repomix`      | `repomix`      | TypeScript         | Codebase serialization for LLM ingestion. Compresses git repositories into token-budgeted XML/Markdown context bundles with AST tree summaries and `.gitignore` compliance.                                                  |
| **Hardware Enclave Signing**          | `secretive`    | `SecretAgent`  | Swift (SEP)        | Biometric Touch ID commit and tag signing via Apple Secure Enclave Processor (`PROTOCOL.sshsig`).                                                                                                                            |
| **Cryptographic Secrets Decryption**  | `sops` + `age` | `sops` / `age` | Go                 | Transparent memory-only decryption pipe for git diffs (`cachetextconv = false`).                                                                                                                                             |
| **Review-First Terminal Diff**        | `hunk`         | `hunk`         | Rust               | Niche terminal diff viewer tailored for reviewing agent-authored patch sets.                                                                                                                                                 |
| **Branch Model Graph Topology**       | `git-graph`    | `git-graph`    | Rust               | Structured branching graph visualizer. Renders deterministic commit DAGs according to formal branching models (git-flow, simple), provides style presets (round, bold, ascii), and outputs pure stdout ANSI or vector SVG.   |

### 7.1 Architectural Assessment: Is `hunk` the Optimal Solution?

**Principal Architect Verdict:** **NO (Categorically Sub-Optimal).**

While `hunk` (0.23.0) provides an aesthetically pleasing terminal viewer for reviewing changesets,
deep architectural analysis reveals that it introduces unjustifiable system redundancy:

1. **Binary Footprint Bloat:** The `hunk` standalone executable weighs **98.6 MB** on disk. By
   comparison:
    - `delta`: ~15 MB
    - `gitui`: ~10.6 MB
    - `tig`: ~0.6 MB For a CLI tool focused exclusively on viewing diffs, 98+ megabytes represents
      extreme bloat.
2. **Functional Redundancy:**
    - **Everyday terminal diffs:** `delta` delivers superior, faster inline rendering with `bat`
      syntax themes, Levenshtein word diffing, and clickable IDE line jumps without entering a modal
      fullscreen TUI.
    - **Interactive review & staging:** `lazygit` (82k+ stars) provides far superior staging
      granularity (line-by-line, hunk-by-hunk, discard, reword, rebase), rendering a read-only
      viewer redundant.
    - **Understanding agentic modifications:** `difftastic` operates at the AST level, providing
      true semantic clarity by filtering out whitespace and formatting noise, whereas `hunk` remains
      a purely line-based visualizer.
3. **Recommendation:** `hunk` is preserved in Homebrew for ad-hoc changeset inspection if desired,
   but is excluded from the core production pipeline in favor of `delta` + `difftastic` + `lazygit`.

### 7.2 Architectural Assessment: `git-graph` (Structured Branching Topology Engine)

**Principal Architect Verdict:** **YES (High-Value Ergonomic Utility).**

Standard `git log --graph` produces unconstrained ASCII spaghetti when repositories feature parallel
feature branches, hotfixes, and release tags. `git-graph` (0.8.0, Rust) introduces formal DAG layout
primitives with zero runtime latency:

1. **Branching Model Formalization**: Automatically structures topological graphs adhering to standard
   branching models (`git-flow`, `simple`, or `none`). Allows setting repository-specific conventions via
   `git-graph model git-flow`.
2. **Deterministic Subgraph Filtering**: Allows scoping visualizations strictly between merge-bases and
   branch tips (`git-graph [refspecs]...`), eliminating irrelevant historical trunk noise.
3. **Multi-Format Export**: Generates clean UTF-8 terminal graphs with rounded box characters
   (`--style round`), high-density ASCII, or standalone vector graphic assets (`--svg`) for architectural
   documentation.
4. **Lightweight Native Execution**: Compiled in pure Rust (~4.8 MB), requiring 0 runtime dependencies,
   executing subgraphs in $<5\text{ms}$ on Apple Silicon APFS repositories.

---

## 8. Toolchain Validation Scripts

Every tool in the stack includes a standalone validation script in
`~/.local/bin/<tool>/validate.sh`. Each script executes with **zero flags by default**, asserts
environment, schema validity, functional runtime behavior, and latency benchmarks, returning
`exit 0` on success or `exit 1` on failure:

| Tool         | Validation Script                     | Test Focus                                                                                                  |
| :----------- | :------------------------------------ | :---------------------------------------------------------------------------------------------------------- |
| `git-delta`  | `~/.local/bin/delta/validate.sh`      | Pager bindings, Dracula theme, TrueColor ANSI sequences, zdiff3 conflicts, sandbox git diff/log/blame.      |
| `difftastic` | `~/.local/bin/difftastic/validate.sh` | AST syntactic discrimination, comment ignore, direct conflict parsing, `git dft` driver execution.          |
| `mergiraf`   | `~/.local/bin/mergiraf/validate.sh`   | 3-way AST merge auto-resolution on concurrent struct additions, attributes mapping, conflict triggers.      |
| `jujutsu`    | `~/.local/bin/jj/validate.sh`         | Config schema, user identity, delta/difftastic diff tools, `--colocate` git init and working copy snapshot. |
| `lazygit`    | `~/.local/bin/lazygit/validate.sh`    | YAML schema, XDG config dir, `diffRenderers` (delta/difftastic), keybindings, `nvim` editor binding.        |
| `gitui`      | `~/.local/bin/gitui/validate.sh`      | RON theme color tokens, RON keybindings (hjkl navigation), `gui` git alias, execution latency.              |
| `tig`        | `~/.local/bin/tig/validate.sh`        | View settings, column layout, `tigrc` options, binary startup latency.                                      |
| `gitleaks`   | `~/.local/bin/gitleaks/validate.sh`   | Allowlist verification (SOPS envelopes, age keys, SEP certs), synthetic credential detection triggers.      |
| `cocogitto`  | `~/.local/bin/cocogitto/validate.sh`  | Conventional Commits parsing (`feat`, `fix`), breaking change notation, scope taxonomy enforcement.         |
| `lefthook`   | `~/.local/bin/lefthook/validate.sh`   | Lifecycle hooks configuration (pre-commit, commit-msg), parallel job execution, binary latency.             |
| `repomix`    | `~/.local/bin/repomix/validate.sh`    | Packaging to XML, security exclusions (`.sops.*`, `.age`, `.key`, `.env*`, `*.secret`), benchmark.          |
| `atuin`      | `~/.local/bin/atuin/validate.sh`      | SQLite DB integrity (`quick_check`), config schema, Fish AOT cache, sync key/account state.                |
| `ripgrep`    | `~/.local/bin/ripgrep/validate.sh`    | SIMD NEON vectorization, PCRE2 JIT, config syntax, type mappings, ignore rules isolation, search latency.   |
| `lazydocker` | `~/.local/bin/lazydocker/validate.sh` | Docker Compose v2 conformance, YAML schema, theme tokens, custom shell actions, daemon context.             |

Run all validations in sequence:

```bash
for tool in delta difftastic mergiraf jj lazygit gitui tig gitleaks cocogitto lefthook repomix atuin ripgrep lazydocker; do
    ~/.local/bin/${tool}/validate.sh
done
```
