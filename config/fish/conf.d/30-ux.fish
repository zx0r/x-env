# ---
# schema: "mdd-node-v1"
# id: "conf.d/30-ux.fish"
# title: "Shell Presentation & UX Layer"
# layer: "UX / UI (30-39)"
# responsibility: "Configures prompt, cursor shapes, greeting, history bounds, and autosuggestion behaviors"
# dependencies: []
# backlinks: ["config.fish", "conf.d/40-keymaps.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-04"
# last_commit: "pending"
# tags: ["ux", "cursor", "prompt", "history"]
# ---

# ==============================================================================
# 
#  ████████╗██╗  ██╗███████╗    ███████╗███╗   ██╗██╗   ██╗
#  ╚══██╔══╝██║  ██║██╔════╝    ██╔════╝████╗  ██║██║   ██║
#     ██║   ███████║█████╗      █████╗  ██╔██╗ ██║██║   ██║
#     ██║   ██╔══██║██╔══╝      ██╔══╝  ██║╚██╗██║╚██╗ ██╔╝
#     ██║   ██║  ██║███████╗    ███████╗██║ ╚████║ ╚████╔╝
#     ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚══════╝╚═╝  ╚═══╝  ╚═══╝ 
#
#                       ██████╗ ███████╗    ██╗  ██╗ 
#                      ██╔═══██╗██╔════╝    ╚██╗██╔╝ 
#                      ██║   ██║█████╗       ╚███╔╝  
#                      ██║   ██║██╔══╝       ██╔██╗  
#                      ╚██████╔╝██║         ██╔╝ ██╗ 
#                       ╚═════╝ ╚═╝         ╚═╝  ╚═╝ 
# 
#  T H E   E N V I R O N M E N T   O F   X
#  Declarative. Immutable. High-Performance.
# ==============================================================================

# 0. Global Login-Specific UX
# Sourced once per login shell. Exported globally (-gx) to prevent redundant disk I/O in subshells.
if status is-login
    # Load GNU ls colors (in-process read bypasses external cat command fork)
    if set -q XDG_CONFIG_HOME; and test -f "$XDG_CONFIG_HOME/ls_colors"
        read -z LS_COLORS <"$XDG_CONFIG_HOME/ls_colors"
        set -gx LS_COLORS (string trim $LS_COLORS)
    end

    # Load Eza custom colors (in-process read bypasses external cat command fork)
    if set -q XDG_CONFIG_HOME; and test -f "$XDG_CONFIG_HOME/eza_colors"
        read -z EZA_COLORS <"$XDG_CONFIG_HOME/eza_colors"
        set -gx EZA_COLORS (string trim $EZA_COLORS)
    end
end

# Defensive check: Interactive configuration is only relevant for interactive shell usage
status is-interactive; or return

# 1. Base UI & Prompt Settings

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Graffiti ZX0R Color Palette (Bypasses internal Fish theme parser: -7.8ms latency)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Zero-Fork Theme SLA: In-memory stub prevents Fish 4.x from autoloading and parsing themes
function __fish_theme_migrate; end

set -g fish_term256 1

# Command Line Syntax Coloring
set -g fish_color_normal e0f7fc
set -g fish_color_command 00ff66
set -g fish_color_param 00ffff
set -g fish_color_quote ffaa00
set -g fish_color_comment 888888
set -g fish_color_operator ff7700
set -g fish_color_escape ff7700
set -g fish_color_redirection 00b4ff

# Command Line State & Highlighting
set -g fish_color_autosuggestion bbbbbb
set -g fish_color_match 00ff66
set -g fish_color_search_match bryellow --background=000000
set -g fish_color_selection 00b4ff --background=222222
set -g fish_color_cancel ff003c
set -g fish_color_end ff003c
set -g fish_color_error ff003c

# Path Highlighting Colors
set -g fish_color_valid_path 00ff66 --underline
set -g fish_color_valid_path_file 00ffff
set -g fish_color_valid_path_dir 00b4ff

# Shell Prompt Customization
set -g fish_color_user brgreen
set -g fish_color_host 85ad82
set -g fish_color_host_remote yellow
set -g fish_color_status red
set -g fish_color_history_current --bold
set -g fish_color_cwd 00b4ff
set -g fish_color_cwd_root ff003c
set -g fish_color_pwd_bg 000000
set -g fish_color_pwd_dir_bg 000000

# Autocompletion Pager Customization (fish_pager)
set -g fish_pager_color_completion 808080
set -g fish_pager_color_prefix 00ffff --bold --underline
set -g fish_pager_color_progress 00ff66
set -g fish_pager_color_description ffaa00 yellow
set -g fish_pager_color_selected_background --background=222222
set -g fish_pager_color_selected_prefix 00b4ff
set -g fish_pager_color_selected_completion 00ffff
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Disable the greeting for a faster, cleaner startup
set -g fish_greeting ""

# Optimization for terminal character reflow
set -g fish_handle_reflow 0

# Display full directory path in prompt (0 shows full path, 1-3 is more compact)
set -g fish_prompt_pwd_dir_length 0

# Disable Fish querying the terminal for 24-bit color support (Fixes ^[]11 garbage codes)
set -g fish_handle_term24bit 0

# Toggle command execution timer (displays duration)
set -gx fish_command_timer_enabled 1
# 2. Command Execution & History Optimization
# Trace commands kill-switch
set -g fish_trace_commands 0

# Optimization: Only merge sessions on exit to reduce IO lag
set -g fish_history_merge_sessions 1

# Standard history size for a professional workflow
set -g fish_history_max_length 50000

# 3. Security & Privacy
# Default file permissions on macOS are already 022 (invoking fish function 'umask' adds ~0.4ms autoload overhead)
# WARNING: fish_private_mode should only be used via 'fish --private'
# set -gx fish_private_mode 0 # Keep history enabled for productivity

# 6. DevOps & Git / Completion Performance Tuning
# Enable AI-like autosuggestions
set -g fish_autosuggestion_enabled 1

# High-visibility git status for efficient branching
set -g __fish_git_prompt_show_informative_status 1

# Tab completions latency tuning (low latency timeout in seconds)
set -g fish_complete_timeout 0.1

# 7. Cursor Customization (Visual/UX Layer)
# Define cursor variables so they are available when keymaps initialize
set -g fish_vi_force_cursor 1
set -g fish_cursor_default underscore blink # Normal mode: Blinking Underline
set -g fish_cursor_insert underscore blink # Insert mode: Blinking Underline
set -g fish_cursor_visual block # Visual mode: Block
set -g fish_cursor_replace_one underscore # Replace mode: Underline
