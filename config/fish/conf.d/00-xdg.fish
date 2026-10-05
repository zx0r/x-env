# ---
# schema: "mdd-node-v1"
# id: "conf.d/00-xdg.fish"
# title: "XDG Base Directory Specification & Workspace Taxonomy"
# layer: "Foundation (00-09)"
# responsibility: "Establishes standard XDG directory layout, suppresses vendor forks, and bootstraps ~/x workspace taxonomy"
# dependencies: []
# backlinks: ["config.fish", "conf.d/03-path.fish", "conf.d/01-variables.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-05"
# last_commit: "pending"
# tags: ["xdg", "directory", "bootstrap", "x-workspace", "zero-fork"]
# ---

# 0. Vendor Hook Guard (Zero-Fork SLA Enforcement)
# Fish 4.x loads $__fish_config_dir/conf.d/ BEFORE $__fish_vendor_confdirs/.
# Setting this flag suppresses Homebrew's /opt/homebrew/share/fish/vendor_conf.d/mise-activate.fish
# from executing 'mise activate fish | source' on startup (~40-50ms external fork penalty).
# Runtime dispatch is handled zero-overhead via mise shims in 03-path.fish.
set -gx MISE_FISH_AUTO_ACTIVATE 0

# 1. XDG Base Directories (Idempotent / Fast Fallbacks)
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME "$HOME/.cache"
set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME "$HOME/.local/share"
set -q XDG_STATE_HOME; or set -gx XDG_STATE_HOME "$HOME/.local/state"
set -q XDG_BIN_HOME; or set -gx XDG_BIN_HOME "$HOME/.local/bin"

# Darwin APFS Runtime Dir: Trim trailing slash to eliminate double-slash paths (T//lock)
set -q XDG_RUNTIME_DIR; or begin
    if set -q TMPDIR; and test -n "$TMPDIR"
        set -gx XDG_RUNTIME_DIR (string trim -r -c / "$TMPDIR")
    else
        set -gx XDG_RUNTIME_DIR /tmp
    end
end

# 2. XDG User Directories (Idempotent Environment Inheritance)
set -q XDG_DESKTOP_DIR; or set -gx XDG_DESKTOP_DIR "$HOME/Desktop"
set -q XDG_DOCUMENTS_DIR; or set -gx XDG_DOCUMENTS_DIR "$HOME/Documents"
set -q XDG_DOWNLOADS_DIR; or set -gx XDG_DOWNLOADS_DIR "$HOME/Downloads"
set -q XDG_PICTURES_DIR; or set -gx XDG_PICTURES_DIR "$HOME/Pictures"
set -q XDG_VIDEOS_DIR; or set -gx XDG_VIDEOS_DIR "$HOME/Movies"
set -q XDG_MUSIC_DIR; or set -gx XDG_MUSIC_DIR "$HOME/Music"
set -q XDG_PUBLICSHARE_DIR; or set -gx XDG_PUBLICSHARE_DIR "$HOME/Public"

# 3. Meta-Workspace Taxonomy (~/x Human-Agent Ecosystem)
set -q X_ROOT; or set -gx X_ROOT "$HOME/x"
set -q X_AGENTS; or set -gx X_AGENTS "$X_ROOT/agents" # AI Agent Hub (Skills, Rules, MCP)
set -q X_BRAIN; or set -gx X_BRAIN "$X_ROOT/brain" # Knowledge Base / Cognitive Graph
set -q X_CONFIG; or set -gx X_CONFIG "$X_ROOT/config" # WaC / Dotfiles / Environment Substrate
set -q X_DEV; or set -gx X_DEV "$X_ROOT/dev" # Engineering & Development Space

# 4. Idempotent Workspace Provisioning (In-Memory Guard / Zero-Disk SLA)
# Validates authentic workspace sentinels; bypasses disk writes if already initialized
if not set -q __X_WORKSPACE_BOOTSTRAPPED
    test -d "$X_DEV/own" -a -d "$X_AGENTS" -a -d "$XDG_BIN_HOME"
    or command mkdir -p -m 700 $X_ROOT/{agents,brain,config} $X_ROOT/dev/{nda,own} "$XDG_BIN_HOME"
    set -gx __X_WORKSPACE_BOOTSTRAPPED 1
end
