# System Design & Modular Architecture
### Path: `~/.ssh/docs/architecture/system-design.md`

---

## 1. Modular Configuration Precedence (OpenSSH First-Match-Wins)

### 1.1 The Specification
Under `ssh_config(5)`:
* Declarations are evaluated sequentially from top to bottom.
* For each parameter, **the first obtained value wins**. Subsequent declarations matching the same host are discarded.
* The `Include` directive expands wildcard globs in **strict lexical order**.

```
LEXICOGRAPHICAL FILE PROCESSING ORDER (RFC 4251 DOMAINS)
┌─────────────────────────────────┐
│     conf.d/10_hosts.conf        │ ──► [01–79] Target Scoping (readconf.c)
│     Git Remotes & Infrastructure │     Evaluated first (First-Match-Wins)
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│   conf.d/80_connection.conf    │ ──► [80–84] RFC 4254 Connection Protocol
│   Multiplexing & Channel Timings│     Darwin 104-byte safe socket hash (%C)
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│  conf.d/85_authentication.conf  │ ──► [85–89] RFC 4252 User Authentication
│  Secure Enclave Touch ID Socket │     IdentitiesOnly & Auth Method Locking
└────────────────┬────────────────┘
                 │
┌────────────────▼────────────────┐
│    conf.d/90_transport.conf     │ ──► [90–99] RFC 4253 Transport Layer
│    Post-Quantum KEX & AES-GCM   │     Terrapin Immunity & RekeyLimit
└─────────────────────────────────┘
```

### 1.2 Numeric Partitioning & Protocol Domains
To guarantee that specific host definitions are never overridden by global wildcard defaults:
* **`01–79 (Target Scoping)`**: Dedicated endpoints, Git remotes, gateway routers, and specialized host keys (`10_hosts.conf`). Includes non-interactive Git optimizations (`ObscureKeystrokeTiming no`, `VerifyHostKeyDNS no`).
* **`80–84 (Connection Protocol, RFC 4254)`**: Transport engine, multiplexer configuration, fail-closed port forwarding (`ExitOnForwardFailure yes`), network resilience (`ConnectionAttempts 3`), device containment (`Tunnel no`), and granular channel inactivity timeouts (`ChannelTimeout session=15m direct-tcpip=30m forwarded-tcpip=30m`) in `80_connection.conf`.
* **`85–89 (User Authentication, RFC 4252)`**: Hardware identity agent routing, identity gating (`IdentitiesOnly yes`), and complete lockdown of legacy hostbased trust (`HostbasedAuthentication no`) in `85_authentication.conf`.
* **`90–99 (Transport Layer, RFC 4253)`**: Catch-all `Host *` defaults, Post-Quantum hybrid key exchange (`mlkem768x25519-sha256`), AEAD ciphers (`aes256-gcm`), cryptographic guardrails (`WarnWeakCrypto yes`, `RequiredRSASize 4096`), CA signature hardening (`CASignatureAlgorithms`), host key rotation (`UpdateHostKeys ask`), and PFS rekeying in `90_transport.conf`.

---

## 2. Darwin XNU Kernel Socket Architecture

### 2.1 The 104-Byte `sockaddr_un` Limit
In macOS Darwin (XNU kernel), Unix domain sockets are constrained by the C kernel structure definition in `sys/un.h`:

```c
struct sockaddr_un {
    unsigned char sun_len;
    sa_family_t   sun_family;
    char          sun_path[104]; /* 104 bytes maximum, including NUL terminator */
};
```

If a socket pathname exceeds 104 bytes, the `bind()` or `connect()` system call truncates or fails with `EINVAL` or `ENAMETOOLONG`.

### 2.2 Naive vs. Deterministic Hashed Paths
* **Naive Path** (`~/.ssh/cm/%r@%h:%p`):
  Expanding a long user and fully qualified domain name (FQDN) like `deploy@k8s-control-plane-us-east-1.production.corp.internal:22` evaluates to 118 bytes, crashing the connection.
* **Principal Solution** (`ControlPath ~/.ssh/cm-%C`):
  The OpenSSH `%C` token generates a deterministic 40-character SHA1 hash of `%l%h%p%r` (local host, remote host, port, remote user).
  Path length evaluation:
  `/Users/x0r/.ssh/cm-aed65089d77250c9a7e0e91eefbd657fa3b8581d` = **59 bytes**.
  This guarantees 100% mathematical immunity to Darwin kernel buffer overflows across any hostname length.

---

## 3. Toolchain & Workspace Integration

### 3.1 Kitty GPU Terminal (Terminfo Streaming)
Modern terminals like Kitty (`xterm-kitty`) provide truecolor and GPU-accelerated rendering. However, remote servers often lack the `xterm-kitty` terminfo entry, causing curses applications (`vim`, `htop`, `tmux`) to fail with:
`Error opening terminal: xterm-kitty`.

**Remediation**:
* In `~/.config/kitty/ssh.conf`:
  ```conf
  share_connections yes
  env TERM=xterm-256color
  env COLORTERM=truecolor
  ```
* Kitty automatically transfers the terminfo database to `~/.terminfo` on remote hosts when invoking `kitten ssh` (`kssh`).

### 3.2 Tmux Multiplexer Environment Sync
When the Secretive background agent restarts, tmux panes may retain stale `SSH_AUTH_SOCK` environment variables:
* In `~/.config/tmux/tmux.conf`:
  ```tmux
  set -ga update-environment "SSH_AUTH_SOCK SSH_CONNECTION SSH_CLIENT COLORTERM TERM_PROGRAM"
  ```
* Paired with the persistent symlink `~/.ssh/ssh_auth_sock`, tmux panes maintain uninterrupted connectivity to the active agent socket.

### 3.3 Fish Shell Dynamic Agent Routing
In `~/.config/fish/conf.d/11-identity-agent.fish`:
1. **Inbound SSH Guard**: If connecting *into* the Mac over SSH, the forwarded agent socket is preserved to prevent deadlocks on Touch ID (which requires physical presence).
2. **Hardware Resolution**: If local, routes to Secretive container socket (`~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh`).
3. **AOT Cache**: Eliminates redundant filesystem operations via exported session caching.
