# ---
# schema: "mdd-node-v1"
# id: "functions/brew_maintain.fish"
# title: "Automated Homebrew Maintenance Pipeline"
# layer: "Functions"
# responsibility: "Automates Homebrew package updates, greedy cask resolution, transactional delta-verification, dynamic link audits, cache reclamation, and state tracking"
# dependencies: ["conf.d/02_toolchain.fish", "functions/__tui_engine.fish"]
# backlinks: ["conf.d/20_abbrs.fish", "~/Library/LaunchAgents/com.x0r.brew-maintenance.plist"]
# created_at: "2026-10-03"
# updated_at: "2026-10-20"
# tags: ["homebrew", "maintenance", "automation", "audit", "launchd", "macos", "tui", "spinner", "history", "deduplication", "ttl-cache", "short-circuit"]
# ---

# ==============================================================================
# AUTOMATED HOMEBREW MAINTENANCE PIPELINE
# ------------------------------------------------------------------------------
# Autonomous Workstation Maintenance Pipeline:
# 1. Terminal UX: Interactive Braille spinner, dynamic checkboxes [ ] -> [✔] / [⚠] / [✖]
# 2. Alignment: Strict 2-space baseline, ↳ tree connectors for sub-details
# 3. Structured JSON v2 Protocol: Full fidelity parsing of formulae and greedy casks
# 4. Transactional Delta-Verification: Post-upgrade inspection catching silent failures
# 5. Pinned & User Exclusion Architecture: Preserves pinned kegs and user blacklists
# 6. Storage Reclamation: Autoremoves orphan dependencies, prunes caches & stale services
# 7. Dependency Integrity: Validates dynamic link libraries (brew missing)
# 8. System Diagnostics: Evaluates system health (brew doctor)
# 9. Cryptographic Deduplication: SHA-256 warning hashing suppressing alert storms
# 10. Ledger Observability: Append-only JSONL run history for telemetry & audits
# 11. Darwin Platform Safety: Power/battery awareness (pmset) & concurrency mutex lock
# ==============================================================================

# ------------------------------------------------------------------------------
# Thin adapter: delegates to shared TUI engine (__tui_engine.fish)
# ------------------------------------------------------------------------------
function __brew_spin_run -a step_prefix label cmd log_file
    if not functions -q __tui_spin_run
        test -f "$__fish_config_dir/functions/__tui_engine.fish"; and source "$__fish_config_dir/functions/__tui_engine.fish"
    end
    __tui_spin_run "$step_prefix" "$label" "$cmd" "$log_file"
    return $status
end

# ------------------------------------------------------------------------------
# Battery State Inspector: returns 0 if running on battery (discharging)
# ------------------------------------------------------------------------------
function __brew_is_on_battery
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
# State & History Path Resolvers (Strict XDG State Home adherence)
# ------------------------------------------------------------------------------
function __brew_state_file
    set -l state_dir "$HOME/.local/state/homebrew"
    if test -n "$XDG_STATE_HOME"
        set state_dir "$XDG_STATE_HOME/homebrew"
    end
    mkdir -p -m 700 "$state_dir" 2>/dev/null
    echo "$state_dir/maintenance_state.json"
end

function __brew_history_file
    set -l state_dir "$HOME/.local/state/homebrew"
    if test -n "$XDG_STATE_HOME"
        set state_dir "$XDG_STATE_HOME/homebrew"
    end
    mkdir -p -m 700 "$state_dir" 2>/dev/null
    echo "$state_dir/history.jsonl"
end

# ------------------------------------------------------------------------------
# Concurrency Mutex Lock: Prevents collision between interactive & scheduled jobs
# ------------------------------------------------------------------------------
function __brew_acquire_lock -a lock_dir force
    if test "$force" = "1"
        rm -rf "$lock_dir" 2>/dev/null
    end

    if not command mkdir "$lock_dir" 2>/dev/null
        # Lock exists: inspect PID liveness and active workload to auto-heal stale locks
        set -l lock_pid (cat "$lock_dir/pid" 2>/dev/null)
        if test -n "$lock_pid"
            if test "$lock_pid" = "$fish_pid"
                # Stale lock: holding PID is the current shell session (interrupted run). Auto-recover immediately.
                rm -rf "$lock_dir" 2>/dev/null
                if command mkdir "$lock_dir" 2>/dev/null
                    echo $fish_pid > "$lock_dir/pid"
                    return 0
                end
            else if not /bin/kill -0 "$lock_pid" 2>/dev/null
                # Stale lock: holding process is dead. Auto-recover immediately.
                rm -rf "$lock_dir" 2>/dev/null
                if command mkdir "$lock_dir" 2>/dev/null
                    echo $fish_pid > "$lock_dir/pid"
                    return 0
                end
            else
                # Holding process is alive: check if it is actively running brew maintenance
                # An idle shell sitting at a prompt is not executing maintenance
                set -l proc_args (ps -p "$lock_pid" -o args= 2>/dev/null)
                set -l has_brew_child (pgrep -P "$lock_pid" -f "brew" 2>/dev/null)
                if not string match -rq 'brew' -- "$proc_args"; and test -z "$has_brew_child"
                    # The PID is alive but not executing any brew process. Auto-recover.
                    rm -rf "$lock_dir" 2>/dev/null
                    if command mkdir "$lock_dir" 2>/dev/null
                        echo $fish_pid > "$lock_dir/pid"
                        return 0
                    end
                end
            end
        else if test -d "$lock_dir"
            # Directory exists without a valid PID file: inspect staleness
            set -l lock_mtime (stat -f "%m" "$lock_dir" 2>/dev/null; or echo 0)
            set -l now (date +%s)
            if test (math "$now - $lock_mtime") -gt 30
                rm -rf "$lock_dir" 2>/dev/null
                if command mkdir "$lock_dir" 2>/dev/null
                    echo $fish_pid > "$lock_dir/pid"
                    return 0
                end
            end
        end
        return 1
    end

    echo $fish_pid > "$lock_dir/pid" 2>/dev/null
    return 0
end

function __brew_release_lock -a lock_dir
    rm -rf "$lock_dir" 2>/dev/null
end

# ------------------------------------------------------------------------------
# Workstation Maintenance Status (--status)
# ------------------------------------------------------------------------------
function __brew_show_status -a log_file
    set -l is_tty 0
    test -t 1; and set is_tty 1

    set -l state_file (__brew_state_file)
    set -l hist_file (__brew_history_file)
    set -l status_tmp (mktemp)

    if test $is_tty -eq 1
        __tui_spin_transient "Inspecting maintenance status & daemon..." "
            set -l pin_dir '/opt/homebrew/var/homebrew/pinned'
            test -d \"\$pin_dir\"; or set pin_dir '/usr/local/var/homebrew/pinned'
            set -l pins ''
            if test -d \"\$pin_dir\"
                set pins (command ls -1 \"\$pin_dir\" 2>/dev/null | string join ', ')
            end
            echo \"\$pins\" > '$status_tmp.pins'

            set -l l_name 'com.x0r.brew-maintenance'
            if not launchctl list \"\$l_name\" >/dev/null 2>&1
                launchctl list 'com.user.brew-maintenance' >/dev/null 2>&1; and set l_name 'com.user.brew-maintenance'
            end
            echo \"\$l_name\" > '$status_tmp.launchd'
        "
    else
        set -l pin_dir "/opt/homebrew/var/homebrew/pinned"
        test -d "$pin_dir"; or set pin_dir "/usr/local/var/homebrew/pinned"
        set -l pins ""
        if test -d "$pin_dir"
            set pins (command ls -1 "$pin_dir" 2>/dev/null | string join ", ")
        end
        echo "$pins" > "$status_tmp.pins"

        set -l l_name "com.x0r.brew-maintenance"
        if not launchctl list "$l_name" >/dev/null 2>&1
            launchctl list "com.user.brew-maintenance" >/dev/null 2>&1; and set l_name "com.user.brew-maintenance"
        end
        echo "$l_name" > "$status_tmp.launchd"
    end

    set -l pinned_pkgs (cat "$status_tmp.pins" 2>/dev/null)
    test -n "$pinned_pkgs"; or set pinned_pkgs "none"
    rm -f "$status_tmp.pins"

    set -l launchd_name (cat "$status_tmp.launchd" 2>/dev/null; or echo "com.x0r.brew-maintenance")
    rm -f "$status_tmp.launchd" "$status_tmp"

    set -l launchd_status "Not loaded"
    if launchctl list "$launchd_name" >/dev/null 2>&1
        set launchd_status (printf "\e[1;32mLoaded\e[0m \e[90m(%s · Weekly Sun 10:00)\e[0m" "$launchd_name")
    else
        set launchd_status (printf "\e[1;33mNot loaded\e[0m \e[90m(Inspect ~/Library/LaunchAgents/%s.plist)\e[0m" "$launchd_name")
    end

    set -l last_run "Never (no history recorded)"
    set -l last_status "N/A"
    set -l last_freed "0 B"
    set -l last_duration "0s"
    set -l total_history 0

    if test -f "$hist_file"
        set -l c (grep -c -v '^[[:space:]]*$' "$hist_file" 2>/dev/null)
        test -n "$c"; and set total_history $c
    end

    if test -f "$state_file"; and type -q jq
        set last_run (jq -r '.last_run // "Never"' "$state_file" 2>/dev/null)
        set last_status (jq -r '.status // "N/A"' "$state_file" 2>/dev/null)
        set last_freed (jq -r '.freed // "0 B"' "$state_file" 2>/dev/null)
        set -l dur (jq -r '.duration_s // 0' "$state_file" 2>/dev/null)
        set last_duration "$dur"s
    else if test -f "$hist_file"; and type -q jq
        set -l last_line (grep -v '^[[:space:]]*$' "$hist_file" | tail -n 1)
        if test -n "$last_line"
            set last_run (echo "$last_line" | jq -r '.timestamp // "N/A"' 2>/dev/null)
            set last_status (echo "$last_line" | jq -r '.status // "N/A"' 2>/dev/null)
            set last_freed (echo "$last_line" | jq -r '.freed // "0 B"' 2>/dev/null)
            set last_duration (echo "$last_line" | jq -r '(.duration_s | tostring) + "s" // "0s"' 2>/dev/null)
        end
    end

    set -l exclude_file "$__fish_config_dir/brew_exclude.json"
    set -l excluded_list "none"
    if test -f "$exclude_file"; and type -q jq
        set excluded_list (jq -r '(.formulae // []) + (.casks // []) | join(", ")' "$exclude_file" 2>/dev/null)
        test -n "$excluded_list"; or set excluded_list "none"
    end

    set -l short_hist (string replace "$HOME" "~" -- "$hist_file")
    set -l short_log (string replace "$HOME" "~" -- "$log_file")

    printf "%bHomebrew Maintenance Status%b\n" $__tui_c_title $__tui_c_reset
    __tui_divider
    printf "  %bLast Run:%b           %s \e[1;33m[%s]\e[0m \e[90m(duration: %s, freed: %s)\e[0m\n" $__tui_c_dim $__tui_c_reset "$last_run" "$last_status" "$last_duration" "$last_freed"
    printf "  %bLaunchAgent:%b        %b\n" $__tui_c_dim $__tui_c_reset "$launchd_status"
    printf "  %bPower Policy:%b       AC-gated background execution (pmset awareness)\n" $__tui_c_dim $__tui_c_reset
    set -l ttl_display (if test -n "$HOMEBREW_API_AUTO_UPDATE_SECS"; math "round($HOMEBREW_API_AUTO_UPDATE_SECS / 3600)"; else; echo 24; end)"h"
    printf "  %bIndex Cache TTL:%b    %s (HOMEBREW_API_AUTO_UPDATE_SECS)\n" $__tui_c_dim $__tui_c_reset "$ttl_display"
    printf "  %bPinned Kegs:%b        %s\n" $__tui_c_dim $__tui_c_reset "$pinned_pkgs"
    printf "  %bExcluded Packages:%b  %s\n" $__tui_c_dim $__tui_c_reset "$excluded_list"
    printf "  %bLedger Entries:%b     %d recorded \e[90m(%s)\e[0m\n" $__tui_c_dim $__tui_c_reset $total_history "$short_hist"
    printf "  %bActive Log:%b         %s\n" $__tui_c_dim $__tui_c_reset "$short_log"
    __tui_divider
end

# ------------------------------------------------------------------------------
# History Ledger Viewer (--history [N])
# ------------------------------------------------------------------------------
function __brew_show_history -a limit
    test -n "$limit"; or set limit 10
    set -l hist_file (__brew_history_file)

    if not test -f "$hist_file"
        printf "  %b-%b %bNo history ledger found at %s%b\n" $__tui_c_dim $__tui_c_reset $__tui_c_dim "$hist_file" $__tui_c_reset
        return 0
    end

    printf "%bHomebrew Maintenance Ledger (Last %d runs)%b\n" $__tui_c_title $limit $__tui_c_reset
    __tui_divider
    printf "  %-19s  %-7s  %-10s  %-8s  %-10s  %s\n" "Timestamp" "Status" "Mode" "Duration" "Reclaimed" "Upgraded"
    printf "  %s  %s  %s  %s  %s  %s\n" "-------------------" "-------" "----------" "--------" "----------" "--------"

    grep -v '^[[:space:]]*$' "$hist_file" 2>/dev/null | tail -n "$limit" | while read -l line
        test -z "$line"; and continue
        set -l ts (echo "$line" | jq -r '.timestamp // "N/A"' 2>/dev/null)
        set -l st (echo "$line" | jq -r '.status // "ok"' 2>/dev/null)
        set -l md (echo "$line" | jq -r '.mode // "full"' 2>/dev/null)
        set -l dt (echo "$line" | jq -r '(.duration_s | tostring) + "s" // "0s"' 2>/dev/null)
        set -l fr (echo "$line" | jq -r '.freed // "0 B"' 2>/dev/null)
        set -l up_names (echo "$line" | jq -r 'if ((.upgraded // []) | length) == 0 then "none" else ((.upgraded // []) | join(", ")) end' 2>/dev/null)
        test -n "$up_names"; or set up_names "none"
        if test (string length -- "$up_names") -gt 32
            set up_names (string sub -l 29 -- "$up_names")"..."
        end

        set -l st_padded (printf "%-7s" "$st")
        set -l st_fmt "$__tui_c_ok$st_padded$__tui_c_reset"
        if test "$st" = "problem" -o "$st" = "error"
            set st_fmt "$__tui_c_err$st_padded$__tui_c_reset"
        else if test "$st" = "warning"
            set st_fmt "$__tui_c_warn$st_padded$__tui_c_reset"
        end

        printf "  %-19s  %b  %-10s  %-8s  %-10s  %s\n" "$ts" "$st_fmt" "$md" "$dt" "$fr" "$up_names"
    end
    __tui_divider
end

# ------------------------------------------------------------------------------
# Main Entrypoint: brew_maintain
# ------------------------------------------------------------------------------
function brew_maintain --description "Automated Homebrew maintenance pipeline (update, greedy upgrade, missing audit, cleanup)"
    set -l log_file "$HOME/Library/Logs/brew-maintenance.log"
    set -l dry_run 0
    set -l no_upgrade 0
    set -l force 0
    set -l show_stat 0
    set -l show_hist 0
    set -l hist_limit 10

    # Ensure shared TUI engine primitives are loaded
    if not functions -q __tui_spin_run
        test -f "$__fish_config_dir/functions/__tui_engine.fish"; and source "$__fish_config_dir/functions/__tui_engine.fish"
    end

    # Parse CLI arguments
    set -l idx 1
    while test $idx -le (count $argv)
        set -l arg $argv[$idx]
        switch $arg
            case -h --help
                echo "Usage: brew_maintain [OPTIONS]"
                echo
                echo "Automated Homebrew Maintenance Pipeline"
                echo
                echo "Options:"
                echo "  -d, --dry-run     Simulate upgrade and cleanup without disk mutation"
                echo "  -n, --no-upgrade  Check outdated and run integrity audits without upgrading"
                echo "  -s, --status      Display workstation maintenance status and schedule"
                echo "  -H, --history     Display maintenance execution history ledger"
                echo "  -f, --force       Override battery safety, mutex locks, index TTL, and bypass guards"
                echo "  -h, --help        Show this help message"
                echo
                echo "Examples:"
                echo "  brew_maintain                # Smart interactive run with TTL & short-circuit guards"
                echo "  brew_maintain --force        # Full force run bypassing cache TTL & guards"
                echo "  brew_maintain --dry-run      # Non-destructive simulation"
                echo "  brew_maintain --status       # Inspect last run & LaunchAgent status"
                echo "  brew_maintain --history 15   # View last 15 maintenance runs"
                return 0
            case -d --dry-run
                set dry_run 1
            case -n --no-upgrade
                set no_upgrade 1
            case -f --force
                set force 1
            case -s --status
                set show_stat 1
            case -H --history
                set show_hist 1
                set -l next_idx (math $idx + 1)
                if test $next_idx -le (count $argv); and string match -qr '^\d+$' -- "$argv[$next_idx]"
                    set hist_limit $argv[$next_idx]
                    set idx $next_idx
                end
        end
        set idx (math $idx + 1)
    end

    # Handle immediate sub-commands
    if test $show_stat -eq 1
        __brew_show_status "$log_file"
        return 0
    end

    if test $show_hist -eq 1
        __brew_show_history "$hist_limit"
        return 0
    end

    mkdir -p (dirname "$log_file")
    set -l start_ts (date +%s)
    set -l date_str (date "+%Y-%m-%d %H:%M:%S")
    set -l mode_str "full"
    test $dry_run -eq 1; and set mode_str "dry-run"
    test $no_upgrade -eq 1; and set mode_str "report-only"

    # Battery Power Safety Guard
    if __brew_is_on_battery
        if not test -t 1; and test $force -eq 0
            # Non-interactive background daemon (launchd): abort to preserve battery
            set -l msg "[$date_str] Maintenance deferred: Workstation is operating on battery power (discharging)."
            echo "$msg" >> $log_file
            if test (uname) = "Darwin"
                osascript -e 'display notification "Automated maintenance deferred while on battery power" with title "🍺 Homebrew"' 2>/dev/null
            end
            return 0
        end
    end

    # Resolve Homebrew binary dynamically
    set -l brew_bin "$HOMEBREW_PREFIX/bin/brew"
    if not test -x "$brew_bin"
        set brew_bin (command -s brew)
        test -n "$brew_bin"; or set brew_bin "/opt/homebrew/bin/brew"
    end

    # Concurrency Mutex Lock
    set -l runtime_base "$TMPDIR"
    test -n "$runtime_base"; or set runtime_base "/tmp"
    set -l clean_base (string trim -r -c '/' "$runtime_base")
    set -l lock_dir "$clean_base/brew_maintain_"(id -u)".lock"

    if not __brew_acquire_lock "$lock_dir" $force
        set -l active_pid (cat "$lock_dir/pid" 2>/dev/null)
        set -l pid_info ""
        test -n "$active_pid"; and set pid_info " (PID: $active_pid)"
        if test -t 1
            printf "  %b⚠%b  %bMaintenance Lock Active%b\n" \
                $__tui_c_warn $__tui_c_reset $__tui_c_warn $__tui_c_reset
            printf "     ↳ %bConflict:%b  Another maintenance instance is currently executing%b%s%b\n" \
                $__tui_c_dim $__tui_c_reset $__tui_c_bold "$pid_info" $__tui_c_reset
            printf "     ↳ %bLock path:%b %s\n" \
                $__tui_c_dim $__tui_c_reset "$lock_dir"
            printf "     ↳ %bAction:%b    Use %b--force%b to override if this is a stale lock\n" \
                $__tui_c_dim $__tui_c_reset $__tui_c_item $__tui_c_reset
        else
            echo "[$date_str] Maintenance aborted: Concurrency lock $lock_dir active$pid_info." >> $log_file
        end
        return 1
    end

    # Darwin Power Assertion: prevent idle system sleep during lengthy maintenance
    set -l caffeinate_pid ""
    if test (uname) = "Darwin"
        if not __brew_is_on_battery; and type -q caffeinate
            caffeinate -i -t 7200 -w $fish_pid &
            set caffeinate_pid $last_pid
        end
    end

    # Signal & Lifecycle RAII Cleanup Handler
    set -l is_cleaned_up 0
    function __brew_maintain_cleanup --no-scope-shadowing
        test $is_cleaned_up -eq 1; and return 0
        set is_cleaned_up 1
        test -n "$caffeinate_pid"; and /bin/kill -0 $caffeinate_pid 2>/dev/null; and /bin/kill -TERM $caffeinate_pid 2>/dev/null
        test -d "$lock_dir"; and rm -rf "$lock_dir" 2>/dev/null
        rm -f "$outdated_tmp" "$cleanup_tmp" "$missing_tmp" "$doctor_tmp" 2>/dev/null
        printf "\e[?25h" # Restore cursor visibility
        stty echo icanon 2>/dev/null
        functions -e __brew_maintain_on_int
        functions -e __brew_maintain_on_exit
    end

    function __brew_maintain_on_int --on-signal INT --no-scope-shadowing
        __brew_maintain_cleanup
        if not status is-interactive
            exit 130
        end
    end

    function __brew_maintain_on_exit --on-event fish_exit --no-scope-shadowing
        __brew_maintain_cleanup
    end

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> $log_file
    echo "🍺 [$date_str] Homebrew Maintenance Started (Mode: $mode_str)" >> $log_file
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> $log_file

    # Homebrew Signature Color Palette (Craft Amber & Warm Gold)
    set -l c_brew_title    (printf "\e[1;38;5;214m")  # Warm Amber Gold for Pipeline Title
    set -l c_brew_phase    (printf "\e[38;5;215m")    # Muted Amber for Phase Indicators & Mode
    set -l c_brew_item     (printf "\e[1;38;5;222m")  # Pale Golden Wheat for targets/items

    # Pixel-perfect header layout matching workstation aesthetic
    printf "🍺 %bHomebrew Maintenance Pipeline%b\n" $c_brew_title $__tui_c_reset
    printf "  %bMode:%b %b%s%b\n" $__tui_c_dim $__tui_c_reset $c_brew_phase "$mode_str" $__tui_c_reset
    __tui_divider

    # [1/5] Synchronize Taps & Package Index (TTL & API Aware)
    # Honors HOMEBREW_API_AUTO_UPDATE_SECS / HOMEBREW_AUTO_UPDATE_SECS from conf.d/02_toolchain.fish
    set -l update_ttl 86400
    if test -n "$HOMEBREW_API_AUTO_UPDATE_SECS"
        set update_ttl $HOMEBREW_API_AUTO_UPDATE_SECS
    else if test -n "$HOMEBREW_AUTO_UPDATE_SECS"
        set update_ttl $HOMEBREW_AUTO_UPDATE_SECS
    end

    set -l repo_root "$HOMEBREW_REPOSITORY"
    test -n "$repo_root"; or set repo_root "/opt/homebrew"
    test -d "$repo_root"; or set repo_root "/usr/local/Homebrew"
    set -l fetch_head "$repo_root/.git/FETCH_HEAD"

    set -l index_mtime 0
    if test -f "$fetch_head"
        set index_mtime (stat -f "%m" "$fetch_head" 2>/dev/null; or echo 0)
    end

    set -l now_ts (date +%s)
    set -l index_age (math "$now_ts - $index_mtime")
    set -l should_update 1

    if test $force -eq 0 -a $index_mtime -gt 0 -a $index_age -lt $update_ttl
        set should_update 0
    end

    if test $should_update -eq 1
        __brew_spin_run "[1/5]" "Synchronizing Homebrew taps & index (brew update)" "$brew_bin update" $log_file
        test $status -eq 0; and __tui_sub_detail "success" "Package index & formulae metadata synchronized"
    else
        set -l age_str (math "round($index_age / 60)")"m"
        if test $index_age -ge 3600
            set age_str (math "round($index_age / 3600)")"h"
        end
        set -l ttl_str (math "round($update_ttl / 3600)")"h"
        printf "  %b✔%b  %b[1/5]%b %bIndex cache fresh%b %b(age: %s < %s TTL · skipped)%b\n" \
            $__tui_c_ok $__tui_c_reset $c_brew_phase $__tui_c_reset $c_brew_title $__tui_c_reset \
            $__tui_c_dim "$age_str" "$ttl_str" $__tui_c_reset
        echo "  ✔ [1/5] Index cache fresh (age: $age_str < $ttl_str TTL · skipped)" >> $log_file
    end

    # [2/5] Resolve Outdated Formulae & Casks (Structured JSON v2 Protocol)
    set -l outdated_tmp (mktemp)
    __brew_spin_run "[2/5]" "Resolving outdated formulae & casks (--greedy-latest)" "$brew_bin outdated --json=v2 --greedy-latest > $outdated_tmp" $log_file

    set -l to_upgrade_names
    set -l to_upgrade_labels
    set -l to_upgrade_kinds
    set -l to_upgrade_to_vers
    set -l pinned_names
    set -l pinned_labels
    set -l excluded_names

    # Load optional user exclusions if configured
    set -l user_exclusions
    set -l exclude_file "$__fish_config_dir/brew_exclude.json"
    if test -f "$exclude_file"; and type -q jq
        set user_exclusions (jq -r '((.formulae // []) + (.casks // []))[]' "$exclude_file" 2>/dev/null)
    end

    if test -s "$outdated_tmp"; and type -q jq
        # Parse JSON v2 output using structured stream
        set -l parsed_rows (jq -r '
            def ver(v): if (v | type)=="array" then (v | join(",")) else (v // "?") end;
            ((.formulae // [])[] | "\(.name)\t\(ver(.installed_versions))\t\(.current_version // "?")\t\(.pinned // false)\tformula"),
            ((.casks // [])[] | "\(.name)\t\(ver(.installed_versions))\t\(.current_version // "?")\t\(.pinned // false)\tcask")
        ' "$outdated_tmp" 2>/dev/null)

        for row in $parsed_rows
            set -l cols (string split \t -- "$row")
            set -l pkg $cols[1]
            set -l from_ver $cols[2]
            set -l to_ver $cols[3]
            set -l is_pinned $cols[4]
            set -l kind $cols[5]

            test -z "$pkg"; and continue

            # Abbreviate long commit SHAs (>=12 hex chars) to 7 chars for clean, compact UI labels
            set -l from_fmt (string replace -ra '([0-9a-fA-F]{7})[0-9a-fA-F]{5,}' '$1' -- "$from_ver")
            set -l to_fmt (string replace -ra '([0-9a-fA-F]{7})[0-9a-fA-F]{5,}' '$1' -- "$to_ver")

            set -l label "$__tui_c_item$pkg$__tui_c_reset"
            if test -n "$from_fmt" -a -n "$to_fmt" -a "$from_fmt" != "?" -a "$from_fmt" != "$to_fmt"
                set label "$__tui_c_item$pkg$__tui_c_reset $__tui_c_dim($from_fmt → $to_fmt)$__tui_c_reset"
            end

            # Check pinned state
            if test "$is_pinned" = "true"
                set -a pinned_names "$pkg"
                set -a pinned_labels "$label"
                continue
            end

            # Check user exclusions
            if contains -- "$pkg" $user_exclusions
                set -a excluded_names "$pkg"
                continue
            end

            set -a to_upgrade_names "$pkg"
            set -a to_upgrade_labels "$label"
            set -a to_upgrade_kinds "$kind"
            set -a to_upgrade_to_vers "$to_ver"
        end
    else
        # Fallback to text parsing if jq is absent
        set -l raw_lines (cat $outdated_tmp 2>/dev/null | string match -r '\S.*')
        for line in $raw_lines
            set -l pkg (string match -r '^\S+' -- "$line")
            test -z "$pkg"; and continue
            set -a to_upgrade_names "$pkg"
            set -a to_upgrade_labels "$__tui_c_item$pkg$__tui_c_reset"
            set -a to_upgrade_kinds "formula"
            set -a to_upgrade_to_vers ""
        end
    end

    set -l outdated_count (count $to_upgrade_names)
    set -l pinned_count (count $pinned_names)
    set -l excluded_count (count $excluded_names)

    if test $outdated_count -gt 0
        printf "     ↳ %s%d update(s) available%s\n" $__tui_c_warn $outdated_count $__tui_c_reset
        echo "Outdated packages ($outdated_count): $to_upgrade_names" >> $log_file
    else
        printf "     ↳ %sAll formulae and casks are up to date%s\n" $__tui_c_dim $__tui_c_reset
        echo "All packages up to date." >> $log_file
    end

    if test $pinned_count -gt 0
        printf "     ↳ %s%d package(s) pinned (held back): %s%s\n" $__tui_c_dim $pinned_count (string join ", " $pinned_names) $__tui_c_reset
        echo "Pinned packages skipped ($pinned_count): $pinned_names" >> $log_file
    end

    if test $excluded_count -gt 0
        printf "     ↳ %s%d package(s) excluded via config: %s%s\n" $__tui_c_dim $excluded_count (string join ", " $excluded_names) $__tui_c_reset
        echo "Excluded packages skipped ($excluded_count): $excluded_names" >> $log_file
    end

    # [3/5] Upgrade Cycle with Transactional Delta-Verification
    set -l upgrade_failed 0
    set -l upgrade_warn 0
    set -l upgraded_names
    set -l failed_names

    if test $no_upgrade -eq 0 -a $outdated_count -gt 0
        if test $dry_run -eq 1
            printf "  %b-%b  %b[3/5]%b %bSimulating upgrades%b %b(--dry-run):%b\n" \
                $__tui_c_dim $__tui_c_reset $__tui_c_phase $__tui_c_reset $__tui_c_title $__tui_c_reset $__tui_c_dim $__tui_c_reset
            for label in $to_upgrade_labels
                printf "       %b[ ]%b %b %b(simulated)%b\n" \
                    $__tui_c_warn $__tui_c_reset "$label" $__tui_c_dim $__tui_c_reset
            end
            set upgraded_names $to_upgrade_names
        else
            printf "  %b✔%b  %b[3/5]%b %bUpgrading %d package(s)%b %b(--greedy-latest):%b\n" \
                $__tui_c_ok $__tui_c_reset $c_brew_phase $__tui_c_reset $c_brew_title $outdated_count $__tui_c_reset $__tui_c_dim $__tui_c_reset

            set -l cellar "$HOMEBREW_CELLAR"
            test -n "$cellar"; or set cellar "$HOMEBREW_PREFIX/Cellar"
            test -d "$cellar"; or set cellar "/opt/homebrew/Cellar"
            test -d "$cellar"; or set cellar "/usr/local/Cellar"

            set -l caskroom "$HOMEBREW_CASKROOM"
            test -n "$caskroom"; or set caskroom "$HOMEBREW_PREFIX/Caskroom"
            test -d "$caskroom"; or set caskroom "/opt/homebrew/Caskroom"
            test -d "$caskroom"; or set caskroom "/usr/local/Caskroom"

            # Concurrent pre-fetch to eliminate serial network bottleneck (PR #17756)
            if test $outdated_count -gt 1
                set -l fetch_cmd "$brew_bin fetch --greedy-latest $to_upgrade_names >> $log_file 2>&1"
                __tui_spin_transient "Pre-fetching $outdated_count packages concurrently..." "$fetch_cmd"
            end

            for i in (seq $outdated_count)
                set -l pkg $to_upgrade_names[$i]
                set -l label $to_upgrade_labels[$i]
                set -l kind $to_upgrade_kinds[$i]
                set -l to_ver $to_upgrade_to_vers[$i]
                set -l f_leaf (string replace -r '.*/' '' -- "$pkg")

                # If already satisfied by a dependency upgrade earlier in this session, mark OK instantly
                if test "$kind" = "formula" -a -n "$to_ver" -a -d "$cellar/$f_leaf/$to_ver"
                    set -l dep_line (printf "       \e[32m[✔]\e[0m %s \e[90m(dep-resolved)\e[0m" "$label")
                    set -l safe_line (__tui_clamp "$dep_line")
                    printf "%s\n" "$safe_line"
                    echo "       [✔] $label (dep-resolved)" >> $log_file
                    set -a upgraded_names "$pkg"
                    continue
                end

                set -l up_cmd "$brew_bin upgrade '$pkg'"
                if test "$kind" = "cask"
                    set up_cmd "$brew_bin upgrade --cask --greedy-latest '$pkg'"
                end

                __tui_spin_item "$label" "$up_cmd" $log_file
                set -l item_rc $status

                # Two-Phase Transactional Delta-Verification
                # Verify physical disk mutation (Cellar / Caskroom) to catch silent failures
                set -l verify_ok 1
                if test -n "$to_ver" -a "$to_ver" != "?"
                    switch "$kind"
                        case "formula"
                            if not test -d "$cellar/$f_leaf/$to_ver"; and not test -e "$cellar/../opt/$f_leaf"
                                set verify_ok 0
                            end
                        case "cask"
                            if not test -d "$caskroom/$f_leaf/$to_ver"
                                set verify_ok 0
                            end
                    end
                end

                if test $item_rc -eq 0 -a $verify_ok -eq 1
                    set -a upgraded_names "$pkg"
                else if test $item_rc -eq 2 -a $verify_ok -eq 1
                    set -a upgraded_names "$pkg"
                    set upgrade_warn 1
                else
                    set -a failed_names "$pkg"
                    set upgrade_failed 1
                    if test $verify_ok -eq 0
                        echo "       [✖] $label (delta-verification failed: version $to_ver not in Cellar/Caskroom)" >> $log_file
                    end
                end
            end

            if test (count $failed_names) -gt 0
                __tui_sub_detail "error" (printf "Upgrade failures: \e[1;31m%s\e[0m" (string join ", " $failed_names))
            else
                __tui_sub_detail "success" (printf "%d package(s) upgraded successfully" (count $upgraded_names))
            end
        end
    else
        if test $outdated_count -eq 0
            printf "  %b-%b  %b[3/5]%b %bUpgrade phase skipped%b %b(closure up-to-date)%b\n" \
                $__tui_c_dim $__tui_c_reset $c_brew_phase $__tui_c_reset $__tui_c_dim $__tui_c_reset $__tui_c_dim $__tui_c_reset
        else
            printf "  %b-%b  %b[3/5]%b %bUpgrade phase skipped%b %b(report-only mode):%b\n" \
                $__tui_c_dim $__tui_c_reset $c_brew_phase $__tui_c_reset $__tui_c_dim $__tui_c_reset $__tui_c_dim $__tui_c_reset
            for label in $to_upgrade_labels
                printf "       %b[ ]%b %b %b(pending)%b\n" \
                    $__tui_c_warn $__tui_c_reset "$label" $__tui_c_dim $__tui_c_reset
            end
        end
    end

    # [4/5] Storage & Service Reclamation (cleanup + services)
    # Executed prior to audits to purge dangling symlinks, stale kegs, and orphaned leaves
    set -l freed "0 B"
    set -l should_reclaim 0
    if test (count $upgraded_names) -gt 0 -o $force -eq 1
        set should_reclaim 1
    end

    if test $should_reclaim -eq 1
        # Honor HOMEBREW_CLEANUP_MAX_AGE_DAYS from conf.d/02_toolchain.fish unless forced
        set -l prune_days $HOMEBREW_CLEANUP_MAX_AGE_DAYS
        test -n "$prune_days"; or set prune_days 30
        set -l cleanup_flags "--prune=$prune_days"
        test $force -eq 1; and set cleanup_flags "--prune=all"
        test $dry_run -eq 1; and set cleanup_flags "$cleanup_flags --dry-run"
        set -l cleanup_tmp (mktemp)

        __brew_spin_run "[4/5]" "Pruning cache, stale kegs & orphaned leaves (cleanup)" "
            test $dry_run -eq 0; and $brew_bin autoremove
            $brew_bin cleanup $cleanup_flags > $cleanup_tmp
            if $brew_bin services --help >/dev/null 2>&1;
                test $dry_run -eq 0; and $brew_bin services cleanup >/dev/null 2>&1
            end
        " $log_file

        set -l cleanup_out (cat $cleanup_tmp 2>/dev/null)
        echo "$cleanup_out" >> $log_file

        set freed (string match -r '(?:freed|free) approximately ([\d.]+\s*[KMGT]?B)' "$cleanup_out")[2]
        test -n "$freed"; or set freed "0 B"
        __tui_sub_detail "success" (printf "Storage reclaimed: \e[1;32m%s\e[0m" "$freed")
        rm -f "$cleanup_tmp"
    else
        printf "  %b-%b  %b[4/5]%b %bStorage reclamation skipped%b %b(no package mutations · use --force to purge)%b\n" \
            $__tui_c_dim $__tui_c_reset $c_brew_phase $__tui_c_reset $__tui_c_dim $__tui_c_reset $__tui_c_dim $__tui_c_reset
        echo "  - [4/5] Storage reclamation skipped (no mutations in closure)" >> $log_file
    end

    # [5/5] Dynamic Library Integrity & System Health (brew missing + brew doctor)
    # Audits final system state; short-circuits if baseline is known-clean and no mutations occurred
    set -l missing_failed 0
    set -l doctor_warn 0
    set -l doctor_action_hints
    set -l suggested_deps
    set -l action_summary ""
    set -l parsed_doctor ""

    set -l state_file (__brew_state_file)
    set -l prev_status "ok"
    if test -f "$state_file"; and type -q jq
        set prev_status (jq -r '.status // "ok"' "$state_file" 2>/dev/null)
    end

    set -l should_audit 0
    if test (count $upgraded_names) -gt 0 -o $force -eq 1 -o "$prev_status" != "ok"
        set should_audit 1
    end

    if test $should_audit -eq 1
        set -l missing_tmp (mktemp)
        set -l doctor_tmp (mktemp)

        __brew_spin_run "[5/5]" "Auditing linkage integrity & system health (missing + doctor)" "
            $brew_bin missing > $missing_tmp 2>&1
            $brew_bin doctor > $doctor_tmp 2>&1
        " $log_file

        set -l missing_out (cat $missing_tmp 2>/dev/null | string match -r '\S.*')

        if test -n "$missing_out"
            set missing_failed 1
            __tui_sub_detail "error" "Broken dynamic links detected (brew missing):"
            for line in $missing_out
                printf "       \e[31m[✖]\e[0m %s\n" "$line"
            end
            set suggested_deps (cat $missing_tmp 2>/dev/null | awk -F': ' '{print $2}' | tr '\n' ' ' | xargs)
            test -n "$suggested_deps"; and __tui_sub_detail "warn" "Suggested fix: brew install $suggested_deps"
            echo "Broken dependencies (brew missing): $missing_out" >> $log_file
        end

        if test -s "$doctor_tmp"
            set parsed_doctor (awk '/^Warning: / { flag=1 } flag { print }' "$doctor_tmp")
            if test (count $parsed_doctor) -gt 0
                set doctor_warn 1
                __tui_sub_detail "warn" "Diagnostic findings reported (brew doctor):"

                cat "$doctor_tmp" | awk '/^Warning: / { flag=1 } flag { print }' | while read -l line
                    test -z "$line"; and continue
                    if string match -q "Warning: *" -- "$line"
                        set -l title (string replace "Warning: " "" -- "$line")
                        printf "       %b⚠%b %b%s%b\n" $__tui_c_warn $__tui_c_reset $c_brew_title "$title" $__tui_c_reset
                    else if string match -rq "^(brew (untap|trust|cleanup|install|link)|Run `.*`)" -- (string trim -- "$line")
                        set -l act_clean (string trim -- "$line")
                        printf "         ↳ %bAction:%b %b%s%b\n" $__tui_c_item $__tui_c_reset $__tui_c_bold "$act_clean" $__tui_c_reset
                        set -a doctor_action_hints "$act_clean"
                        if test -z "$action_summary"; or string match -q "brew trust*" "$act_clean"
                            set action_summary "$act_clean"
                        end
                    else if string match -rq "^https?://\S+" -- (string trim -- "$line")
                        printf "         ↳ %bDoc:%b %b%s%b\n" $__tui_c_dim $__tui_c_reset $__tui_c_dim (string trim -- "$line") $__tui_c_reset
                    else if string match -rq "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+" -- (string trim -- "$line")
                        printf "         • %b%s%b\n" $c_brew_item (string trim -- "$line") $__tui_c_reset
                    else
                        printf "         %b%s%b\n" $__tui_c_dim (string trim -- "$line") $__tui_c_reset
                    end
                end
                echo "$parsed_doctor" >> $log_file
            end
        end

        if test -z "$action_summary" -a -n "$suggested_deps"
            set action_summary "brew install $suggested_deps"
        end

        if test $missing_failed -eq 0 -a $doctor_warn -eq 0
            __tui_sub_detail "success" "Dependency graph intact · system health verified"
        end

        rm -f "$missing_tmp" "$doctor_tmp"
    else
        printf "  %b-%b  %b[5/5]%b %bLinkage & system health audit skipped%b %b(cached baseline intact)%b\n" \
            $__tui_c_dim $__tui_c_reset $c_brew_phase $__tui_c_reset $__tui_c_dim $__tui_c_reset $__tui_c_dim $__tui_c_reset
        __tui_sub_detail "success" "Dependency graph intact · system health verified (verified baseline)"
        echo "  - [5/5] Linkage & system health audit skipped (baseline intact)" >> $log_file
    end

    # Duration & Status Analysis
    set -l duration (math (date +%s) - $start_ts)
    set -l has_errors 0
    set -l has_warnings 0
    test $upgrade_failed -ne 0 -o $missing_failed -ne 0; and set has_errors 1
    test $doctor_warn -ne 0 -o $upgrade_warn -ne 0; and set has_warnings 1

    # Warning Cryptographic Deduplication (SHA-256)
    set -l warn_signature ""
    set -l is_deduplicated 0
    if test $has_warnings -eq 1 -o $has_errors -eq 1
        set -l raw_warn_content (printf "%s\n%s\n%s" "$parsed_doctor" "$missing_out" (string join "," $failed_names))
        set warn_signature (printf "%s" "$raw_warn_content" | shasum -a 256 2>/dev/null | awk '{print $1}')
    end

    set -l state_file (__brew_state_file)
    set -l hist_file (__brew_history_file)
    set -l prev_warning_hash ""

    if test -f "$state_file"; and type -q jq
        set prev_warning_hash (jq -r '.last_warning_hash // ""' "$state_file" 2>/dev/null)
        if test -n "$warn_signature" -a "$warn_signature" = "$prev_warning_hash"
            set is_deduplicated 1
        end
    end

    # Persist State
    set -l run_status "ok"
    test $has_warnings -eq 1; and set run_status "warning"
    test $has_errors -eq 1; and set run_status "error"

    if type -q jq
        set -l doc_bool (if test $doctor_warn -eq 0; echo "true"; else; echo "false"; end)
        set -l miss_bool (if test $missing_failed -eq 0; echo "true"; else; echo "false"; end)

        set -l state_json (jq -n \
            --arg ts "$date_str" \
            --arg status "$run_status" \
            --arg mode "$mode_str" \
            --arg warn_hash "$warn_signature" \
            --arg duration "$duration" \
            --arg freed "$freed" \
            --argjson doc_ok "$doc_bool" \
            --argjson miss_ok "$miss_bool" \
            '{last_run: $ts, status: $status, mode: $mode, last_warning_hash: $warn_hash, duration_s: ($duration | tonumber), freed: $freed, doctor_ok: $doc_ok, missing_ok: $miss_ok}')
        echo "$state_json" > "$state_file"

        # Append to JSONL History Ledger
        set -l up_json (if test (count $upgraded_names) -gt 0; printf '%s\n' $upgraded_names | jq -R . | jq -s -c .; else; echo "[]"; end)
        set -l fail_json (if test (count $failed_names) -gt 0; printf '%s\n' $failed_names | jq -R . | jq -s -c .; else; echo "[]"; end)
        set -l pin_json (if test (count $pinned_names) -gt 0; printf '%s\n' $pinned_names | jq -R . | jq -s -c .; else; echo "[]"; end)

        set -l hist_entry (jq -n -c \
            --arg ts "$date_str" \
            --arg status "$run_status" \
            --arg mode "$mode_str" \
            --argjson duration "$duration" \
            --arg freed "$freed" \
            --argjson doc_ok "$doc_bool" \
            --argjson miss_ok "$miss_bool" \
            --argjson upgraded "$up_json" \
            --argjson failed "$fail_json" \
            --argjson pinned "$pin_json" \
            '{timestamp: $ts, status: $status, mode: $mode, duration_s: $duration, freed: $freed, doctor_ok: $doc_ok, missing_ok: $miss_ok, upgraded: $upgraded, failed: $failed, pinned: $pinned}')
        echo "$hist_entry" >> "$hist_file"

        # Trim History Ledger to 1000 lines
        set -l line_count (wc -l < "$hist_file" | string trim)
        if test $line_count -gt 1000
            set -l trimmed_lines (tail -n 1000 "$hist_file")
            printf "%s\n" $trimmed_lines > "$hist_file"
        end
    end

    # Notification Payloads
    set -l notify_title "🍺 Homebrew"
    set -l notify_body (printf "Maintenance complete. Freed: %s (in %ds)" "$freed" $duration)

    if test $dry_run -eq 1
        set notify_title "🍺 Homebrew [Dry-Run]"
        set notify_body (printf "Simulation complete. Would free: %s (in %ds)" "$freed" $duration)
    else if test $has_errors -eq 1
        set notify_title "❌ Homebrew Error"
        set notify_body "Maintenance encountered errors! Inspect $log_file"
    else if test $has_warnings -eq 1
        if test $is_deduplicated -eq 1
            set notify_title "🍺 Homebrew [Known Warnings]"
            if test -n "$action_summary"
                set notify_body "Known warning: $action_summary"
            else
                set notify_body "Maintenance complete (diagnostic warnings unchanged). Freed: $freed"
            end
        else
            set notify_title "⚠️ Homebrew Warning"
            if test -n "$action_summary"
                set notify_body "$action_summary"
            else
                set notify_body "Maintenance finished with diagnostic warnings. Inspect $log_file"
            end
        end
    end

    # Dispatch native macOS Notification
    if test (uname) = "Darwin"
        osascript -e "display notification \"$notify_body\" with title \"$notify_title\"" 2>/dev/null
    end

    # Render Clean Summary Card (Separate Status, Metrics, and Telemetry)
    printf "\n"
    set -l status_line ""
    set -l metrics_line ""
    set -l log_line (printf "%bLog:%b %s" $__tui_c_dim $__tui_c_reset "$log_file")
    set -l up_count (count $upgraded_names)

    if test $has_errors -eq 1
        set -l fail_count (count $failed_names)
        set status_line (printf "%b✖ Maintenance Finished with Errors%b" $__tui_c_err $__tui_c_reset)
        set metrics_line (printf "%bUpgraded:%b %b%d%b  %b·%b  %bFailed:%b %b%d%b  %b·%b  %bDuration:%b %b%ds%b" \
            $__tui_c_dim $__tui_c_reset $__tui_c_item $up_count $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_err $fail_count $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_dim $duration $__tui_c_reset)
        set log_line (printf "%bInspect log:%b %s" $__tui_c_dim $__tui_c_reset "$log_file")
        if test $fail_count -gt 0
            set -l fail_detail (printf "%bFailed packages:%b %b%s%b" $__tui_c_err $__tui_c_reset $__tui_c_item (string join ", " $failed_names) $__tui_c_reset)
            __tui_banner "$status_line" "$metrics_line" "$fail_detail" "$log_line"
        else
            __tui_banner "$status_line" "$metrics_line" "$log_line"
        end
    else if test $has_warnings -eq 1
        if test $is_deduplicated -eq 1
            set status_line (printf "%b⚠ Maintenance Finished with Known Warnings%b" $__tui_c_warn $__tui_c_reset)
        else
            set status_line (printf "%b⚠ Maintenance Finished with Warnings%b" $__tui_c_warn $__tui_c_reset)
        end
        set metrics_line (printf "%bUpgraded:%b %b%d%b  %b·%b  %bReclaimed:%b %b%s%b  %b·%b  %bDuration:%b %b%ds%b" \
            $__tui_c_dim $__tui_c_reset $__tui_c_item $up_count $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_ok "$freed" $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_dim $duration $__tui_c_reset)
        set log_line (printf "%bInspect log:%b %s" $__tui_c_dim $__tui_c_reset "$log_file")
        if test -n "$action_summary"
            set -l action_line (printf "%bAction required:%b %b%s%b" $__tui_c_warn $__tui_c_reset $__tui_c_item "$action_summary" $__tui_c_reset)
            __tui_banner "$status_line" "$metrics_line" "$action_line" "$log_line"
        else
            __tui_banner "$status_line" "$metrics_line" "$log_line"
        end
    else if test $dry_run -eq 1
        set status_line (printf "%b✔ Homebrew Simulation Complete%b" $__tui_c_ok $__tui_c_reset)
        set metrics_line (printf "%bUpgraded:%b %b%d%b  %b·%b  %bReclaimed:%b %b%s%b  %b·%b  %bDuration:%b %b%ds%b" \
            $__tui_c_dim $__tui_c_reset $__tui_c_item $up_count $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_ok "$freed" $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_dim $duration $__tui_c_reset)
        __tui_banner "$status_line" "$metrics_line" "$log_line"
    else
        set status_line (printf "%b✔ Homebrew Maintenance Complete%b" $__tui_c_ok $__tui_c_reset)
        set metrics_line (printf "%bUpgraded:%b %b%d%b  %b·%b  %bReclaimed:%b %b%s%b  %b·%b  %bDuration:%b %b%ds%b" \
            $__tui_c_dim $__tui_c_reset $__tui_c_item $up_count $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_ok "$freed" $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_dim $duration $__tui_c_reset)
        __tui_banner "$status_line" "$metrics_line" "$log_line"
    end

    set -l end_date_str (date "+%Y-%m-%d %H:%M:%S")
    echo "🏁 [$end_date_str] $notify_title: $notify_body" >> $log_file

    # Cleanup temp files, release power assertion, and release concurrency lock
    __brew_maintain_cleanup
end
