# ---
# schema: "mdd-node-v1"
# id: "config.fish"
# title: "Main Configuration Entrypoint"
# layer: "Entrypoint / Orchestrator"
# responsibility: "Orchestrates login-specific and interactive-specific shell initialization tasks."
# dependencies: ["conf.d/*"]
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-10-04"
# last_commit: "pending"
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
#       • 00-xdg.fish            -> Bootstraps XDG Base Directory variables and paths.
#       • 01-variables.fish      -> Core environment variables, locale, and telemetry opt-outs.
#       • 02-brew.fish           -> Static Homebrew prefix mapping (bypasses Ruby shellenv fork).
#       • 03-path.fish           -> In-memory sanitization, mise shims prepend, and AOT cache.
#
#   2.  10–19  | Infrastructure Layer
#       • 10-runtimes.fish       -> SWR cache engine for Mise, Starship, Zoxide, and Atuin.
#       • 11-identity-agent.fish -> Tier 1 Cryptographic Identity (Secretive SEP / SSH agent).
#
#   3.  20–29  | Commands Layer
#       • 20-abbr.fish           -> Workspace abbreviations and system command shortcuts (lazy prompt).
#
#   4.  30–39  | UX & Styling Layer
#       • 30-ux.fish             -> Palette, prompt styling, theme bypass stub, and Vi-cursor states.
#
#   5.  40–49  | Input & Mappings Layer
#       • 40-keymaps.fish        -> Vi-mode keybindings and CLI widget integrations.
#
#   6.  50–59  | Tooling Layer
#       • 50-fzf.fish            -> FZF preview/search options and tree-sitter completion bootstrap.
#
#   (Tier 2/3 Secrets: get-secret, add-secret, with-secret are on-demand autoloaded from functions/)
#
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ━━━ 2. Login-Specific Tasks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if status is-login
    # (Other interactive tasks can go here)
end

# ━━━ 3. Interactive-Specific Tasks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if status is-interactive
    # (Other interactive tasks can go here)
end

# ━━━ 4. Configuration Performance Profiling ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# To benchmark changes and profile shell startup time, use these commands:
#   - hyperfine --warmup 10 'fish -i -c exit'
#   - fish --profile-startup /tmp/fish.prof -ic exit
#   - sort -nrk2 /tmp/fish.prof | head -20
#
# Current Target: Startup Latency < 12ms (Empirical Baseline: 11.0ms ± 0.7ms, Target: 8–10ms)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
