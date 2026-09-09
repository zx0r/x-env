# ---
# schema: "mdd-node-v1"
# id: "config.fish"
# title: "Main Configuration Entrypoint"
# layer: "Entrypoint / Orchestrator"
# responsibility: "Orchestrates login-specific and interactive-specific shell initialization tasks."
# dependencies: ["conf.d/*"]
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-07-05"
# last_commit: "4a88e01116ee306d32c5739ebe70316c29791cbf"
# tags: ["entrypoint", "lifecycle", "bootstrap", "orchestration"]
# ---

# NOTE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
#  ███████ ██ ███████ ██   ██
#  ██      ██ ██      ██   ██
#  █████   ██ ███████ ███████
#  ██      ██      ██ ██   ██
#  ██      ██ ███████ ██   ██
#
#  Author       : zx0r
#  License      : MIT License
#  Description  : Fish Shell Entrypoint
#  Contact Info : https://github.com/zx0r
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━ 1. Bootstrap & Lifecycle Order ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# The Fish shell automatically evaluates configuration files located in the
# ~/.config/fish/conf.d/ directory in lexicographical (ASCII) sorting order
# prior to executing this main config.fish entrypoint.
#
# To achieve deterministic dependency resolution and guarantee a safe execution
# sequence, a decade-spaced (decimal) modular topology is enforced:
#
#   1.  00–09  | Foundation Layer
#       • 00-xdg.fish       -> Bootstraps XDG Base Directory variables and paths.
#       • 01-path.fish      -> In-memory sanitization and normalization of $PATH.
#       • 01-variables.fish -> Core environment variables, locale, and telemetry opt-outs.
#       • 02-brew.fish      -> Static Homebrew prefix mapping (bypasses Ruby shellenv fork).
#
#   2.  10–19  | Infrastructure Layer
#       • 10-runtimes.fish  -> Compiled static caching for Mise, Starship, Zoxide, and Atuin.
#       • 11-ssh-gpg.fish   -> SSH/GPG daemon caching and Tmux socket redirection.
#
#   3.  20–29  | Commands Layer
#       • 20-abbr.fish      -> Workspace abbreviations and system command shortcuts.
#
#   4.  30–39  | UX & Styling Layer
#       • 30-ux.fish        -> Asynchronous prompt rendering, greetings, and Vi-cursor states.
#
#   5.  40–49  | Input & Mappings Layer
#       • 40-keymaps.fish   -> Vi-mode keybindings and CLI widget integrations.
#
#   6.  50–59  | Tooling Layer
#       • 50-utils.fish     -> Tool-specific configurations (FZF options, Bat, Neovim).
#
#   7.  90–99  | Extension Layer
#       • 99-local.fish     -> Machine-specific secret overrides (git-ignored).
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━ 2. Login-Specific Tasks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Sourced once per login shell. All variables are exported (-gx) so they are
# inherited by all subsequent nested subshells without redundant disk I/O.
if status is-login
    # Load GNU ls colors (in-process read bypasses external cat command fork)
    #
    # Generated/compiled via trapd00r/LS_COLORS upstream:
    #   curl -fsSL https://raw.githubusercontent.com/trapd00r/LS_COLORS/refs/heads/master/lscolors.csh -o /tmp/lscolors.csh
    #   sed -n "s/^setenv LS_COLORS '\(.*\)'/\1/p" /tmp/lscolors.csh > ~/.config/ls_colors
    #
    if test -f "$XDG_CONFIG_HOME/ls_colors"
        read -z LS_COLORS <"$XDG_CONFIG_HOME/ls_colors"
        set -gx LS_COLORS (string trim $LS_COLORS)
    end

    # Load Eza custom colors (in-process read bypasses external cat command fork)
    if test -f "$XDG_CONFIG_HOME/eza_colors"
        read -z EZA_COLORS <"$XDG_CONFIG_HOME/eza_colors"
        set -gx EZA_COLORS (string trim $EZA_COLORS)
    end
end

# ━━━ 3. Interactive-Specific Tasks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Load interactive color theme configuration if present
if status is-interactive
    set -l theme_path "$XDG_CONFIG_HOME/fish/themes/colorscheme.fish"
    if test -f "$theme_path"
        source "$theme_path"
    end
end

# ━━━ 4. Configuration Performance Profiling ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# To benchmark changes and profile shell startup time, use these commands:
#   - hyperfine --warmup 10 'fish -i -c exit'
#   - fish --profile-startup /tmp/fish.prof -ic exit
#   - sort -nrk2 /tmp/fish.prof | head -20
#
# Current Target: Startup Latency < 50ms (Current Performance: ~40ms)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
