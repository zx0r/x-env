# ---
# schema: "mdd-node-v1"
# id: "functions/__tui_engine.fish"
# title: "Shared Terminal UX Primitives"
# layer: "Functions"
# responsibility: "Provides reusable TUI primitives (spinners, checkboxes, formatted output, notifications) for interactive shell tools"
# dependencies: []
# backlinks: ["functions/brew_maintain.fish", "functions/storage_audit.fish", "functions/storage_clean.fish"]
# created_at: "2026-10-03"
# updated_at: "2026-10-05"
# tags: ["tui", "spinner", "ux", "shared", "primitives"]
# ---

# ==============================================================================
# SHARED TERMINAL UX PRIMITIVES
# ------------------------------------------------------------------------------
# Extracted from duplicated TUI code across brew_maintain, storage_audit, and
# storage_clean into a single, testable, DRY module.
#
# Primitives:
#   __tui_spin_run      Braille spinner wrapping background command execution
#   __tui_print_row     Fixed 3-column aligned output row (name | size | path)
#   __tui_section       Section header with tier color coding
#   __tui_checkbox      Stateful checkbox line item [ ] / [✔] / [✖]
#   __tui_sub_detail    Indented tree connector sub-detail line
#   __tui_divider       Full-width Unicode horizontal rule
#   __tui_banner        Centered title banner with dividers
#   __tui_format_bytes  KiB integer → human-readable string
#   __tui_notify        macOS user notification via osascript
#   __tui_skip          Dimmed skip indicator for deferred operations
# ==============================================================================


# ==============================================================================
# Anchor function: allows Fish to autoload this file when __tui_engine is called
# ==============================================================================
function __tui_engine --description "Anchor function for shared TUI engine primitives"
    return 0
end


# ==============================================================================
# UNIFIED TUI COLOR PALETTE & DESIGN TOKENS
# Initialized with real escape bytes so both %b and %s interpolate color cleanly
# ==============================================================================
set -g __tui_c_reset   (printf "\e[0m")
set -g __tui_c_bold    (printf "\e[1m")
set -g __tui_c_dim     (printf "\e[90m")        # Dim gray: paths, timings, metadata labels
set -g __tui_c_phase   (printf "\e[1;33m")      # Bold yellow: phase indicators [1/5], [2/5]
set -g __tui_c_title   (printf "\e[1;36m")      # Bold cyan: section headers, step titles
set -g __tui_c_item    (printf "\e[38;5;153m")  # Ice Blue: target names, packages, items
set -g __tui_c_div     (printf "\e[38;5;31m")   # Deep steel cyan: card frames & dividers
set -g __tui_c_ok      (printf "\e[1;32m")      # Bold green: success [✔]
set -g __tui_c_warn    (printf "\e[1;33m")      # Bold yellow: warnings [⚠]
set -g __tui_c_err     (printf "\e[1;31m")      # Bold red: errors [✖]
set -g __tui_c_spin    (printf "\e[38;5;141m")  # Purple (Dracula lavender): animated Braille glyphs


# ------------------------------------------------------------------------------
# Animated Braille spinner wrapping background command execution
# Formats step_prefix in yellow phase token and label in cyan title token
# Secondary details/flags in parentheses (e.g. brew update) are dimmed
# Usage: __tui_spin_run "[1/5]" "Scanning packages" "brew outdated" $log_file
# Returns: exit code of the wrapped command
# ------------------------------------------------------------------------------
function __tui_spin_run -a step_prefix label cmd log_file
    set -l is_tty 0
    test -t 1; and set is_tty 1

    # Format step prefix with yellow phase token if needed
    set -l step_fmt "$step_prefix"
    if test -n "$step_fmt"
        if not string match -qr '\x1b\[' -- "$step_fmt"
            string match -qr '^\[' -- "$step_fmt"; or set step_fmt "[$step_fmt]"
            set step_fmt "$__tui_c_phase$step_fmt$__tui_c_reset"
        end
    end

    # Format label: separate primary action from secondary flags / tool details
    set -l label_fmt "$label"
    if test -n "$label_fmt"; and not string match -qr '\x1b\[' -- "$label_fmt"
        if string match -qr '\(.*\)' -- "$label"
            set -l base (string replace -r ' *\(.*' '' -- "$label")
            set -l extra (string match -r '\(.*\)' -- "$label")
            set label_fmt (printf "%b%s%b %b%s%b" $__tui_c_title "$base" $__tui_c_reset $__tui_c_dim "$extra" $__tui_c_reset)
        else
            set label_fmt "$__tui_c_title$label_fmt$__tui_c_reset"
        end
    end

    # Non-interactive fallback (launchd, pipe, cron)
    if test $is_tty -eq 0
        set -l t0 (date +%s)
        fish -c "$cmd" >> $log_file 2>&1
        set -l rc $status
        set -l dt (math (date +%s) - $t0)
        if test $rc -eq 0
            printf "  ✔  %s %s (%ds)\n" "$step_prefix" "$label" $dt | tee -a $log_file
        else
            printf "  ✖  %s %s (failed: %d)\n" "$step_prefix" "$label" $rc | tee -a $log_file
        end
        return $rc
    end

    # Interactive TTY: Animated Braille spinner with cursor management
    set -l start_time (date +%s)
    fish -c "$cmd" >> $log_file 2>&1 &
    set -l pid $last_pid
    set -l spin_chars "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"
    set -l idx 1

    printf "\e[?25l" # Hide cursor

    while /bin/kill -0 $pid 2>/dev/null
        printf "\r\e[2K  %b%s%b  %b %b" $__tui_c_spin $spin_chars[$idx] $__tui_c_reset "$step_fmt" "$label_fmt"
        set idx (math "$idx % 10 + 1")
        sleep 0.08
    end
    wait $pid
    set -l rc $status
    set -l elapsed (math (date +%s) - $start_time)

    printf "\e[?25h" # Restore cursor

    if test $rc -eq 0
        printf "\r\e[2K  %b✔%b  %b %b %b(%ds)%b\n" \
            $__tui_c_ok $__tui_c_reset "$step_fmt" "$label_fmt" $__tui_c_dim $elapsed $__tui_c_reset
        echo "  ✔ $step_prefix $label ({$elapsed}s)" >> $log_file
    else
        printf "\r\e[2K  %b✖%b  %b %b %b(failed: %d)%b\n" \
            $__tui_c_err $__tui_c_reset "$step_fmt" "$label_fmt" $__tui_c_err $rc $__tui_c_reset
        echo "  ✖ $step_prefix $label (failed: $rc)" >> $log_file
    end
    return $rc
end


# ------------------------------------------------------------------------------
# Per-item animated Braille spinner inside checkbox: [⠋] → [✔] / [⚠] / [✖]
# Handles Success (green ✔), Warn (yellow ⚠), Error (red ✖)
# Usage: __tui_spin_item "package (old → new)" "brew upgrade pkg" $log_file
# Returns: 0 on success, 2 on warning, >=1 on error
# ------------------------------------------------------------------------------
function __tui_spin_item -a label cmd log_file
    set -l is_tty 0
    test -t 1; and set is_tty 1

    # Non-interactive fallback (launchd, pipe, cron)
    if test $is_tty -eq 0
        set -l t0 (date +%s)
        set -l item_out (mktemp)
        fish -c "$cmd" > $item_out 2>&1
        set -l rc $status
        set -l dt (math (date +%s) - $t0)
        cat $item_out >> $log_file

        set -l has_warn 0
        if test -f "$item_out"
            string match -qri '\bwarning:' (cat $item_out); and set has_warn 1
        end

        if test $rc -eq 0 -a $has_warn -eq 0
            printf "       \e[32m[✔]\e[0m %b \e[90m(%ds)\e[0m\n" "$label" $dt | tee -a $log_file
            return 0
        else if test $rc -eq 0 -a $has_warn -eq 1
            printf "       \e[33m[⚠]\e[0m %b \e[33m(with warnings)\e[0m \e[90m(%ds)\e[0m\n" "$label" $dt | tee -a $log_file
            return 2
        else
            printf "       \e[31m[✖]\e[0m %b \e[31m(failed: %d)\e[0m\n" "$label" $rc | tee -a $log_file
            return $rc
        end
    end

    # Interactive TTY: Animated Braille spinner inside brackets [⠋] -> [✔] / [⚠] / [✖]
    set -l start_time (date +%s)
    set -l item_out (mktemp)
    fish -c "$cmd" > $item_out 2>&1 &
    set -l pid $last_pid
    set -l spin_chars "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"
    set -l idx 1

    printf "\e[?25l" # Hide cursor

    while /bin/kill -0 $pid 2>/dev/null
        printf "\r\e[2K       %b[%s]%b %b" $__tui_c_spin $spin_chars[$idx] $__tui_c_reset "$label"
        set idx (math "$idx % 10 + 1")
        sleep 0.08
    end
    wait $pid
    set -l rc $status
    set -l elapsed (math (date +%s) - $start_time)
    cat $item_out >> $log_file

    printf "\e[?25h" # Restore cursor

    set -l has_warn 0
    if test -f "$item_out"
        string match -qri '\bwarning:' (cat $item_out); and set has_warn 1
    end

    if test $rc -eq 0 -a $has_warn -eq 0
        # Success: Green checkmark
        printf "\r\e[2K       \e[32m[✔]\e[0m %b \e[90m(%ds)\e[0m\n" "$label" $elapsed
        echo "       [✔] $label ({$elapsed}s)" >> $log_file
        return 0
    else if test $rc -eq 0 -a $has_warn -eq 1
        # Warn: Yellow warning triangle
        printf "\r\e[2K       \e[33m[⚠]\e[0m %b \e[33m(with warnings)\e[0m \e[90m(%ds)\e[0m\n" "$label" $elapsed
        echo "       [⚠] $label (with warnings, {$elapsed}s)" >> $log_file
        return 2
    else
        # Error: Red cross
        printf "\r\e[2K       \e[31m[✖]\e[0m %b \e[31m(failed: %d)\e[0m\n" "$label" $rc
        echo "       [✖] $label (failed: $rc)" >> $log_file
        return $rc
    end
end


# ------------------------------------------------------------------------------
# Transient animated Braille spinner (self-erases upon completion)
# Ideal for diagnostic/audit scan phases: provides live feedback without leaving
# permanent lines or visual clutter in the terminal history.
# Usage: __tui_spin_transient "Scanning workspace targets..." "$cmd"
# ------------------------------------------------------------------------------
function __tui_spin_transient -a label cmd
    set -l is_tty 0
    test -t 1; and set is_tty 1

    if test $is_tty -eq 0
        fish -c "$cmd" >/dev/null 2>&1
        return $status
    end

    fish -c "$cmd" >/dev/null 2>&1 &
    set -l pid $last_pid
    set -l spin_chars "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"
    set -l idx 1

    printf "\e[?25l" # Hide cursor

    while /bin/kill -0 $pid 2>/dev/null
        printf "\r\e[2K  %b%s%b  \e[90m%s\e[0m" $__tui_c_spin $spin_chars[$idx] $__tui_c_reset "$label"
        set idx (math "$idx % 10 + 1")
        sleep 0.08
    end
    wait $pid
    set -l rc $status

    # Erase the spinner line completely and restore cursor
    printf "\r\e[2K\e[?25h"
    return $rc
end


# ------------------------------------------------------------------------------
# Fixed 3-column aligned output row for audit dashboards
# Col 1: 34 chars left (name) | Col 2: 8 chars right bold (size) | Col 3: path (dim gray)
# Usage: __tui_print_row "Cargo Cache" "1.2G" "~/.cargo" [1]
# ------------------------------------------------------------------------------
function __tui_print_row -a name sz loc is_green
    # Strip ANSI escapes from size for correct padding
    set -l clean_sz (string replace -ra '\x1b\[[0-9;]*[a-zA-Z]' '' -- "$sz" | string trim)
    set -l sz_col (printf "%10s" "$clean_sz")

    if test "$is_green" = "1"
        printf "  %s%-34s%s %s%s%s   %s%s%s\n" \
            $__tui_c_item "$name" $__tui_c_reset \
            $__tui_c_ok "$sz_col" $__tui_c_reset \
            $__tui_c_dim "$loc" $__tui_c_reset
    else
        printf "  %s%-34s%s %s%s%s   %s%s%s\n" \
            $__tui_c_item "$name" $__tui_c_reset \
            $__tui_c_err "$sz_col" $__tui_c_reset \
            $__tui_c_dim "$loc" $__tui_c_reset
    end
end


# ------------------------------------------------------------------------------
# Section header with consistent tier color coding (Phase in Yellow, Title in Cyan)
# Usage: __tui_section "1/5" "Project Workspaces & Build Targets"
# ------------------------------------------------------------------------------
function __tui_section
    if test (count $argv) -ge 2
        set -l step "$argv[1]"
        string match -qr '^\[' -- "$step"; or set step "[$step]"
        printf "\n%s%s%s %s%s%s\n" \
            $__tui_c_phase "$step" $__tui_c_reset \
            $__tui_c_title "$argv[2]" $__tui_c_reset
    else
        set -l step "$argv[1]"
        string match -qr '^\[' -- "$step"; or set step "[$step]"
        printf "\n%s%s%s\n" $__tui_c_phase "$step" $__tui_c_reset
    end
end


# ------------------------------------------------------------------------------
# Stateful checkbox line item with semantic status support:
#   1 | success | ✔  → [✔] Green
#   2 | warn | ⚠     → [⚠] Yellow
#  -1 | error | ✖    → [✖] Red
#   skip | info | -  → [-] Dim/Gray
#   0 | pending | *  → [ ] Yellow
# ------------------------------------------------------------------------------
function __tui_checkbox -a state label
    switch "$state"
        case 1 success '✔'
            printf "    %s[✔]%s %b\n" $__tui_c_ok $__tui_c_reset "$label"
        case 2 warn warning '⚠'
            printf "    %s[⚠]%s %b\n" $__tui_c_warn $__tui_c_reset "$label"
        case -1 error fail '✖'
            printf "    %s[✖]%s %b\n" $__tui_c_err $__tui_c_reset "$label"
        case 'skip' 'info' '-'
            printf "    %s[-]%s %b\n" $__tui_c_dim $__tui_c_reset "$label"
        case '*'
            printf "    %s[ ]%s %b\n" $__tui_c_warn $__tui_c_reset "$label"
    end
end


# ------------------------------------------------------------------------------
# Indented tree connector sub-detail line with semantic status support
# Usage: __tui_sub_detail "success" "Dependency graph verified"
#        __tui_sub_detail "warn" "Caveats reported"
#        __tui_sub_detail "error" "Broken dynamic libraries"
# ------------------------------------------------------------------------------
function __tui_sub_detail -a type label
    switch "$type"
        case 1 success '✔'
            printf "     ↳ %s✔%s %b\n" $__tui_c_ok $__tui_c_reset "$label"
        case 2 warn warning '⚠'
            printf "     ↳ %s⚠%s %b\n" $__tui_c_warn $__tui_c_reset "$label"
        case -1 error fail '✖'
            printf "     ↳ %b✖%b %b\n" $__tui_c_err $__tui_c_reset "$label"
        case 'skip' 'info' '-'
            printf "     ↳ %b-%b %b\n" $__tui_c_dim $__tui_c_reset "$label"
        case '*'
            if test -n "$type"
                printf "     ↳ %s %b\n" "$type" "$label"
            else
                printf "     ↳ %b%b%b\n" $__tui_c_dim "$label" $__tui_c_reset
            end
    end
end


# ------------------------------------------------------------------------------
# Dimmed skip/deferred indicator
# Usage: __tui_skip "[3/5]" "Docker prune deferred (run with -a/--all)"
# ------------------------------------------------------------------------------
function __tui_skip -a step_prefix label
    set -l step_fmt "$step_prefix"
    if test -n "$step_fmt"; and not string match -qr '\x1b\[' -- "$step_fmt"
        string match -qr '^\[' -- "$step_fmt"; or set step_fmt "[$step_fmt]"
        set step_fmt (printf "%b%s%b" $__tui_c_phase "$step_fmt" $__tui_c_reset)
    end
    printf "  %b-%b  %b %b%s%b\n" \
        $__tui_c_dim $__tui_c_reset \
        "$step_fmt" \
        $__tui_c_dim "$label" $__tui_c_reset
end


# ------------------------------------------------------------------------------
# Full-width Unicode horizontal rule (70 chars) with color styling
# Usage: __tui_divider ["\e[38;5;31m"]
# ------------------------------------------------------------------------------
function __tui_divider -a color
    set -l c $__tui_c_div
    test -n "$color"; and set c "$color"
    printf "%b%s%b\n" "$c" (string repeat -n 70 "━") $__tui_c_reset
end


# ------------------------------------------------------------------------------
# Multi-line title/summary banner with dividers above and below
# Indents enclosed lines by 2 spaces for consistent terminal card padding
# Usage: __tui_banner [--color="\e[...]"] "Title" "Line 1" "Line 2" ...
# ------------------------------------------------------------------------------
function __tui_banner
    test (count $argv) -eq 0; and return

    set -l div_color $__tui_c_div
    set -l lines $argv

    if string match -qr '^--color=' -- "$argv[1]"
        set div_color (string replace -r '^--color=' '' -- "$argv[1]")
        set lines $argv[2..-1]
    end

    __tui_divider "$div_color"
    for i in (seq (count $lines))
        set -l line "$lines[$i]"
        test -z "$line"; and continue

        if test $i -eq 1; and not string match -qr '\x1b\[' -- "$line"
            printf "  %b%s%b\n" $__tui_c_title "$line" $__tui_c_reset
        else
            printf "  %b\n" "$line"
        end
    end
    __tui_divider "$div_color"
end


# ------------------------------------------------------------------------------
# Convert KiB integer to human-readable byte string
# Usage: set result (__tui_format_bytes 1572864)  → "1.5 GiB"
# ------------------------------------------------------------------------------
function __tui_format_bytes -a kilobytes
    if test -z "$kilobytes" -o "$kilobytes" = "0"
        echo "0 B"
        return
    end

    # Threshold at 1000 MiB (1024000 KB) and 1000 KiB to prevent ugly 4-digit values (e.g. 1018.4 MiB -> 1.0 GiB)
    if test $kilobytes -ge 1024000
        printf "%.1f GiB" (math "$kilobytes / 1048576")
    else if test $kilobytes -ge 1000
        printf "%.1f MiB" (math "$kilobytes / 1024")
    else
        printf "%d KiB" $kilobytes
    end
end


# ------------------------------------------------------------------------------
# macOS user notification via osascript (silent fail on non-Darwin)
# Usage: __tui_notify "Storage Maintenance" "Freed 2.4 GiB in 12s"
# ------------------------------------------------------------------------------
function __tui_notify -a title body
    test (uname) = "Darwin"; or return 0
    osascript -e "display notification \"$body\" with title \"$title\" sound name \"Glass\"" 2>/dev/null
end


# ------------------------------------------------------------------------------
# Quick directory size measurement (dust preferred, du fallback)
# Returns human-readable size string to stdout
# Usage: set sz (__tui_dir_size "/path/to/dir")
# ------------------------------------------------------------------------------
function __tui_dir_size -a dir_path
    test -d "$dir_path"; or return 1

    if type -q dust
        set -l result (dust -d 0 "$dir_path" 2>/dev/null | tail -n 1 | awk '{print $1}')
        test -n "$result" -a "$result" != "0B"; and echo "$result"; and return 0
    end

    # Fallback to du
    set -l result (du -sh "$dir_path" 2>/dev/null | awk '{print $1}')
    test -n "$result" -a "$result" != "0B"; and echo "$result"; and return 0

    return 1
end


# ------------------------------------------------------------------------------
# Quick directory size in KiB (raw numeric, for accumulation)
# Usage: set kb (__tui_dir_size_kb "/path/to/dir")
# ------------------------------------------------------------------------------
function __tui_dir_size_kb -a dir_path
    test -d "$dir_path"; or return 1
    set -l kb (du -sk "$dir_path" 2>/dev/null | awk '{print $1}')
    test -n "$kb"; and echo "$kb"; and return 0
    return 1
end


# ------------------------------------------------------------------------------
# Battery State Inspector: returns 0 if running on battery power (discharging)
# ------------------------------------------------------------------------------
function __tui_is_on_battery
    test (uname) = "Darwin"; or return 1
    if type -q pmset
        set -l batt_out (pmset -g batt 2>/dev/null)
        if string match -q "*Battery Power*" -- "$batt_out"
            return 0
        end
    end
    return 1
end


# ------------------------------------------------------------------------------
# Self-healing PID-aware concurrency mutex lock
# Inspects PID liveness via /bin/kill -0 to automatically recover stale locks
# ------------------------------------------------------------------------------
function __tui_acquire_lock -a lock_dir force
    if test "$force" = "1"
        rm -rf "$lock_dir" 2>/dev/null
    end

    if not command mkdir "$lock_dir" 2>/dev/null
        # Lock exists: inspect PID liveness to auto-heal stale locks
        set -l lock_pid (cat "$lock_dir/pid" 2>/dev/null)
        if test -n "$lock_pid"
            if not /bin/kill -0 "$lock_pid" 2>/dev/null
                # Stale lock: holding process is dead. Auto-recover immediately.
                rm -rf "$lock_dir" 2>/dev/null
                if command mkdir "$lock_dir" 2>/dev/null
                    echo $fish_pid > "$lock_dir/pid" 2>/dev/null
                    return 0
                end
            end
        else if test -d "$lock_dir"
            # Directory exists without a valid PID file: inspect staleness (>30s)
            set -l lock_mtime (stat -f "%m" "$lock_dir" 2>/dev/null; or echo 0)
            set -l now (date +%s)
            if test (math "$now - $lock_mtime") -gt 30
                rm -rf "$lock_dir" 2>/dev/null
                if command mkdir "$lock_dir" 2>/dev/null
                    echo $fish_pid > "$lock_dir/pid" 2>/dev/null
                    return 0
                end
            end
        end
        return 1
    end

    echo $fish_pid > "$lock_dir/pid" 2>/dev/null
    return 0
end

function __tui_release_lock -a lock_dir
    rm -rf "$lock_dir" 2>/dev/null
end
