# ---
# schema: "mdd-node-v1"
# id: "conf.d/11-ssh-gpg.fish"
# title: "SSH & GPG Cryptographic Agent Infrastructure"
# layer: "Infrastructure (10-19)"
# responsibility: "Manages GPG agent, GPG TTY alignment, and SSH agent socket forwarding inside multiplexed shells"
# dependencies: []
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-07-12"
# last_commit: "pending"
# tags: ["ssh", "gpg", "agent", "security", "tmux", "lazy-tty"]
# ---

# Defensive check: SSH/GPG agents and TTY mappings are only relevant for interactive shell usage
status is-interactive; or return

# 1. SSH Socket Forwarding Symlink Pattern (The Tmux & Nested Shell Fix)
# Prevents stale SSH sockets inside terminal multiplexer panes.
set -gx SSH_AUTH_SOCK_LINK "$HOME/.ssh/ssh_auth_sock"

if set -q SSH_AUTH_SOCK
    if test "$SSH_AUTH_SOCK" != "$SSH_AUTH_SOCK_LINK"
        # Ensure the target directory exists
        if not test -d "$HOME/.ssh"
            mkdir -p -m 700 "$HOME/.ssh"
        end

        # Resolve paths natively to avoid /private mismatches and recursive loops
        set -l resolved_sock (path resolve "$SSH_AUTH_SOCK")
        set -l resolved_link (path resolve "$SSH_AUTH_SOCK_LINK")

        if test -S "$resolved_sock"
            if test "$resolved_sock" != "$resolved_link"
                ln -sfh "$SSH_AUTH_SOCK" "$SSH_AUTH_SOCK_LINK"
            end
            set -gx SSH_AUTH_SOCK "$SSH_AUTH_SOCK_LINK"
        end
    end
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. GPG / SSH Agent Emulation Switch
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Set to 1 to delegate all SSH authentication to gpg-agent (professional yubikey setup).
# Set to 0 to use standard ssh-agent.
set -l should_use_gpg_agent_for_ssh 1

if test $should_use_gpg_agent_for_ssh -eq 1
    # Guard: If in an active inbound SSH session, preserve the forwarded SSH agent
    if not set -q SSH_TTY; and not set -q SSH_CLIENT; and not set -q SSH_CONNECTION
        # Point SSH to GPG Agent's SSH emulation socket
        set -gx SSH_AUTH_SOCK "$HOME/.gnupg/S.gpg-agent.ssh"
    end
else
    # Zero-Fork SSH Agent Daemon Cache Loader
    # If no agent socket is provided by the OS/Launchd, load or spawn an agent.
    if not set -q SSH_AUTH_SOCK
        set -l ssh_agent_environment_cache_file "$HOME/.ssh/agent_env"

        # Load environment variables if cache exists
        if test -f "$ssh_agent_environment_cache_file"
            source "$ssh_agent_environment_cache_file" >/dev/null 2>&1
        end

        # Check if we need to respawn the ssh-agent daemon
        set -l should_respawn_ssh_agent 0
        if not set -q SSH_AGENT_PID
            set should_respawn_ssh_agent 1
        else if not kill -0 $SSH_AGENT_PID >/dev/null 2>&1
            set should_respawn_ssh_agent 1
        else if not test -S "$SSH_AUTH_SOCK"
            set should_respawn_ssh_agent 1
        end

        if test $should_respawn_ssh_agent -eq 1
            if not test -d "$HOME/.ssh"
                mkdir -p -m 700 "$HOME/.ssh"
            end

            # Enforce strict file creation permissions (read/write only by owner: 0600)
            set -l original_umask_value (umask)
            umask 077
            ssh-agent -c | string match -rv '^\s*echo\s*' >"$ssh_agent_environment_cache_file"
            umask $original_umask_value

            source "$ssh_agent_environment_cache_file" >/dev/null 2>&1
        end
    end
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. GPG TTY & Background Agent Refresh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ARCHITECTURAL DESIGN: GPG_TTY is lazily initialized inside wrappers (functions/git.fish,
# functions/gpg.fish, etc.) only when cryptographic commands are run.
# This eliminates a synchronous '/usr/bin/tty' process fork on every shell startup.

# Refresh gpg-agent TTY association asynchronously (0 startup blocking)
if type -q gpgconf
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 &
end
