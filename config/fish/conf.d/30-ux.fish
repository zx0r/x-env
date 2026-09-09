# ---
# schema: "mdd-node-v1"
# id: "conf.d/30-ux.fish"
# title: "Shell Presentation & UX Layer"
# layer: "UX / UI (30-39)"
# responsibility: "Configures prompt, cursor shapes, greeting, history bounds, and autosuggestion behaviors"
# dependencies: []
# backlinks: ["config.fish", "conf.d/40-keymaps.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["ux", "cursor", "prompt", "history"]
# ---

# Defensive check: Interactive configuration is only relevant for interactive shell usage
status is-interactive; or return

# 1. Base UI & Prompt Settings
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

# Enable asynchronous prompt rendering for zero-lag command line
set -gx async_prompt_functions fish_prompt

# 2. Command Execution & History Optimization
# Trace commands kill-switch
set -g fish_trace_commands 0

# Ignore duplicate commands in history to keep it clean
set -gx HISTCONTROL ignoredups

# Optimization: Only merge sessions on exit to reduce IO lag
set -g fish_history_merge_sessions 1

# Standard history size for a professional workflow
set -gx fish_history_max_length 50000

# 3. Security & Privacy
# Restrict default file permissions for new files (022 is the industry standard)
umask 022

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

# Enable vi cursor shapes when using tmux
if string match -q -- 'tmux*' $TERM
    set -g fish_vi_force_cursor 1
end
