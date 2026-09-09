# ---
# schema: "mdd-node-v1"
# id: "conf.d/50-utils.fish"
# title: "Third-Party Tooling Integrations"
# layer: "Tooling (50-59)"
# responsibility: "Configures specific options for Bat, Fd, Fzf, Tree-sitter completions, and Homebrew Curl fallbacks"
# dependencies: []
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-07-12"
# last_commit: "pending"
# tags: ["tooling", "utils"]
# ---

# All tooling integrations are strictly relevant for interactive session ergonomics.
# Gating them here avoids unnecessary path lookups and I/O during non-interactive script executions.
status is-interactive; or return

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1. Bat (Cat replacement with syntax highlighting)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if type -q bat
    set -gx BAT_THEME Dracula
    set -gx BAT_PAGER "less -rf"
    set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
    set -gx BAT_CONFIG_DIR "$XDG_CONFIG_HOME/bat"
    set -gx BAT_CONFIG_PATH "$XDG_CONFIG_HOME/bat/bat.conf"
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2. Fd & FZF Integration (Uses -gx memory variables to avoid disk writes)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if type -q fd
    set -gx FZF_CD_COMMAND "fd -t d"
    set -gx FZF_OPEN_COMMAND "fd -H -t f"
    set -gx FZF_FIND_FILE_COMMAND "fd -t f"
    set -gx FZF_CD_WITH_HIDDEN_COMMAND "fd -H -t d"
end


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3. Tree-sitter Completions (Generated dynamically once if installed, zero blocking)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if not test -f "$XDG_CONFIG_HOME/fish/completions/tree-sitter.fish"
    if type -q tree-sitter
        mkdir -p "$XDG_CONFIG_HOME/fish/completions"
        tree-sitter complete --shell fish >"$XDG_CONFIG_HOME/fish/completions/tree-sitter.fish" 2>/dev/null &
    end
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4. Neovim & Nvimx Editor Environments
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if type -q nvimx
    set -e EDITOR
    set -gx EDITOR nvimx
    set -gx VISUAL nvimx
    set -gx GIT_EDITOR nvimx
    set -gx SUDO_EDITOR nvimx
else if type -q nvim
    set -e EDITOR
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx GIT_EDITOR nvim
    set -gx SUDO_EDITOR nvim
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5. Homebrew Curl Environment Setup
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if type -q brew
    if not set -q HOMEBREW_PREFIX
        set -gx HOMEBREW_PREFIX /opt/homebrew
    end

    # Safe check: if Homebrew curl is installed, configure environment variables
    set -l homebrew_curl_path "$HOMEBREW_PREFIX/opt/curl/bin/curl"
    if test -x "$homebrew_curl_path"
        set -gx CURL_HOME "$XDG_CONFIG_HOME/curl"
        set -gx CURL_BIN "$HOMEBREW_PREFIX/opt/curl/bin"

        # SSL certificates
        set -gx CURL_CA_BUNDLE "$HOMEBREW_PREFIX/etc/ca-certificates/cert.pem"
        set -gx SSL_CERT_FILE "$CURL_CA_BUNDLE"

        # Force Homebrew curl
        set -gx HOMEBREW_FORCE_BREWED_CURL 1

        # Add curl to PATH (in-memory)
        if not contains "$CURL_BIN" $PATH
            set -gx PATH "$CURL_BIN" $PATH
        end
    end
end
