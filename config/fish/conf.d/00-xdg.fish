# ---
# schema: "mdd-node-v1"
# id: "conf.d/00-xdg.fish"
# title: "XDG Base Directory Specification"
# layer: "Foundation (00-09)"
# responsibility: "Establishes standard XDG directory layout and bootstraps workstation directories"
# dependencies: []
# backlinks: ["config.fish", "conf.d/01-path.fish", "conf.d/01-variables.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["xdg", "directory", "bootstrap", "x-workspace"]
# ---

# 0. Vendor Hook Guard (Zero-Fork SLA enforcement)
# Fish 4.x loads $__fish_config_dir/conf.d/ BEFORE $__fish_vendor_confdirs/, so setting
# this flag here guarantees it is visible when /opt/homebrew/share/fish/vendor_conf.d/mise-activate.fish
# runs later in the same startup sequence, suppressing its 'mise activate fish | source' (~40ms fork).
# NOTE: -gx is sufficient here - no need for -Ux because this file re-runs on every shell init.
set -gx MISE_FISH_AUTO_ACTIVATE 0

# 1. XDG Base Directories (Performance Optimized / Fallbacks)
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME "$HOME/.cache"
set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME "$HOME/.local/share"
set -q XDG_STATE_HOME; or set -gx XDG_STATE_HOME "$HOME/.local/state"
set -q XDG_BIN_HOME; or set -gx XDG_BIN_HOME "$HOME/.local/bin"
set -q XDG_RUNTIME_DIR; or set -gx XDG_RUNTIME_DIR "$TMPDIR"

# 2. XDG User Directories
set -gx XDG_DESKTOP_DIR "$HOME/Desktop"
set -gx XDG_DOCUMENTS_DIR "$HOME/Documents"
set -gx XDG_DOWNLOADS_DIR "$HOME/Downloads"
set -gx XDG_PICTURES_DIR "$HOME/Pictures"
set -gx XDG_VIDEOS_DIR "$HOME/Movies"
set -gx XDG_MUSIC_DIR "$HOME/Music"
set -gx XDG_PUBLICSHARE_DIR "$HOME/Public"

# 3. Meta-Workspace Taxonomy (~/x Human-Agent Ecosystem)
set -gx X_ROOT "$HOME/x"
set -gx X_AGY "$X_ROOT/agy" # AI Agent Hub (Skills, Rules, MCP)
set -gx X_DEV "$X_ROOT/dev" # Engineering & Development Space
set -gx X_ENV "$X_ROOT/env" # WaC / Dotfiles / Environment Substrate
set -gx X_MIND "$X_ROOT/mind" # Knowledge Base / Cognitive Graph / Obsidian

# 4. Idempotent Workspace Provisioning (In-Memory Guard / Zero-Disk SLA)
if not set -q __X_WORKSPACE_BOOTSTRAPPED
    test -d "$X_DEV/box" -a -d "$XDG_BIN_HOME"
    or mkdir -p -m 700 $X_ROOT/{agy,env,mind} $X_ROOT/dev/{nda,own,box} "$XDG_BIN_HOME"
    set -gx __X_WORKSPACE_BOOTSTRAPPED 1
end
