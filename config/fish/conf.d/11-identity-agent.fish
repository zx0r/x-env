# ---
# schema: "mdd-node-v1"
# id: "conf.d/11-identity-agent.fish"
# title: "Tier 1: Unified Cryptographic Identity Agent"
# layer: "Infrastructure (10-19)"
# responsibility: "Routes SSH agent to Secretive (Secure Enclave hardware keys) with launchd fallback, Tmux stable symlink, inbound SSH guard, and async GPG TTY refresh."
# dependencies: []
# backlinks: ["config.fish", "MAP_OF_CONTENT.md"]
# created_at: "2026-09-22"
# updated_at: "2026-10-04"
# tags: ["ssh", "secure-enclave", "secretive", "tmux", "zero-fork", "identity", "git-signing", "aot-cache"]
# ---

# Tier 1: Unified Cryptographic Identity Agent
#
# Priority chain: Inbound SSH → Secretive (SEP) → launchd ssh-agent
# Private keys never exist on disk when Secretive is active.
# Git commits are signed via PROTOCOL.sshsig (SSH, not GPG).

status is-interactive; or return

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. Inbound SSH Guard
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# When connected via SSH, the forwarded agent socket must be preserved.
# Overwriting it with Secretive would deadlock on Touch ID (no GUI).
if set -q SSH_CLIENT; or set -q SSH_CONNECTION; or set -q SSH_TTY
    if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"
        set -gx __TIER1_IDENTITY "inbound-ssh"
        return
    end
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. Hardware-First Socket Resolution
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Secretive exposes a UNIX domain socket via its sandboxed container.
# If the socket is live → route all SSH/Git operations through Secure Enclave.
# If not → fall back to macOS launchd ssh-agent (system default).
set -l _secretive_sock "$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
set -l _active_sock ""

if test -S "$_secretive_sock"
    set _active_sock "$_secretive_sock"
    set -gx __TIER1_IDENTITY "secretive-hardware"
else if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"
    set _active_sock "$SSH_AUTH_SOCK"
    set -gx __TIER1_IDENTITY "launchd-agent"
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. Tmux Stable Symlink (Zero Process Forks + AOT Cache Guard)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tmux panes inherit SSH_AUTH_SOCK from the server process. When the
# original agent restarts, panes hold a stale socket path. A stable
# symlink at ~/.ssh/ssh_auth_sock always points to the live socket.
#
# AOT cache: if the resolved socket matches the cached value from the
# last startup, skip `ln -sfh` entirely (~200 µs savings per boot).
set -l _stable_link "$HOME/.ssh/ssh_auth_sock"

if test -n "$_active_sock"
    set -l _resolved_sock (path resolve "$_active_sock")

    # AOT guard: skip symlink recreation if socket target is unchanged and symlink is live
    if test "$_resolved_sock" != "$_identity_sock_cache"; or not test -S "$_stable_link"
        set -l _resolved_link (path resolve "$_stable_link" 2>/dev/null)
        if test "$_resolved_sock" != "$_resolved_link"
            test -d "$HOME/.ssh"; or command mkdir -p -m 700 "$HOME/.ssh"
            command ln -sfh "$_active_sock" "$_stable_link"
        end
        # Persist the resolved target across child shells & panes (exported session cache)
        set -gx _identity_sock_cache "$_resolved_sock"
    end
    set -gx SSH_AUTH_SOCK "$_stable_link"
end

