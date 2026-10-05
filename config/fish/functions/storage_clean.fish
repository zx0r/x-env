# ---
# schema: "mdd-node-v1"
# id: "functions/storage_clean.fish"
# title: "Workstation Storage Reclamation Engine"
# layer: "Functions"
# responsibility: "Executes 5-tier systematic workstation storage reclamation with animated spinners, per-item checkboxes, safety governors, dual-circuit telemetry, and macOS notifications"
# dependencies: ["functions/__tui_engine.fish", "functions/trash.fish", "functions/storage_audit.fish"]
# backlinks: ["conf.d/20-abbr.fish"]
# created_at: "2026-10-03"
# updated_at: "2026-10-05"
# tags: ["storage", "clean", "disk", "kondo", "mole", "trash", "cache", "macos", "tui", "spinner", "safety-governor"]
# ---

# ==============================================================================
# WORKSTATION STORAGE RECLAMATION ENGINE (5-Tier Safety Pipeline)
# ------------------------------------------------------------------------------
# Zero-Hazard, Deterministic Cleanup with Interactive TUI:
# 1. Project Workspaces & Builds: kondo age-gated (>14d) + validated SPM/Web cache trashing
# 2. Package Managers & Toolchains: Homebrew, Mise, Micromamba, Cargo, Pnpm, Bun, Pip/uv
# 3. macOS Developer & System Caches: Xcode DerivedData (active process guard)
# 4. Containers & Virtualization: Docker system prune (volumes preserved by default)
# 5. Storage Recycling & Logs: Stale ~/Library/Logs pruning + macOS Trash inspection
#
# Core Safety Invariants:
# - Zero raw rm -rf calls: All file unlinking routes via trash.fish into ~/.Trash
# - Dual-Circuit Telemetry: Tracks physical APFS disk delta and staged trash volumes
# - Volume Preservation Invariant: Docker volumes are NEVER pruned automatically
# - Active Workspace Invariant: Projects modified within 48h are protected
# - Project Manifest Invariant: Build folders (.build, .next) validated against manifests
# - Trash Preservation Invariant: macOS Trash is never emptied implicitly
# - Concurrency Mutex: PID-aware self-healing lock prevents collision
# - Battery Awareness: Non-interactive execution deferred when on battery power
# ==============================================================================

# Helper: Validates that a directory is an authentic, stale build artifact
function __storage_clean_is_safe_artifact -a target run_all
    test -d "$target"; or return 1

    # Invariant 1: Strictly reject Git repository roots or submodules
    test -e "$target/.git"; and return 1

    # Invariant 2: Contextual project manifest validation
    set -l parent (path dirname "$target")
    set -l base (path basename "$target")

    switch "$base"
        case ".build"
            # MUST be an authentic Swift Package Manager project
            test -f "$parent/Package.swift" -o -f "$parent/Package.resolved"; or return 1
        case ".next"
            # MUST be an authentic Next.js project
            test -f "$parent/package.json" -o -f "$parent/next.config.js" -o -f "$parent/next.config.mjs" -o -f "$parent/next.config.ts"; or return 1
        case ".turbo"
            # MUST be an authentic Turborepo project
            test -f "$parent/turbo.json" -o -f "$parent/package.json"; or return 1
        case ".nuxt"
            test -f "$parent/nuxt.config.js" -o -f "$parent/nuxt.config.ts" -o -f "$parent/package.json"; or return 1
        case ".svelte-kit"
            test -f "$parent/svelte.config.js" -o -f "$parent/package.json"; or return 1
        case ".astro"
            test -f "$parent/astro.config.mjs" -o -f "$parent/astro.config.ts" -o -f "$parent/package.json"; or return 1
        case "*"
            return 1
    end

    # Invariant 3: Git tracked files check (never trash tracked files)
    if type -q git; and test -d "$parent/.git"
        git -C "$parent" ls-files --error-unmatch "$target" >/dev/null 2>&1; and return 1
    end

    # Invariant 4: Active workspace protection (mtime < 48 hours unless comprehensive mode)
    if test "$run_all" != "1"
        set -l recent_files (find "$target" -maxdepth 2 -mtime -2 2>/dev/null | head -n 1)
        test -n "$recent_files"; and return 1
    end

    return 0
end

# Helper: Formats KB into human-readable storage unit
function __storage_clean_format_bytes -a kb
    test -n "$kb"; or set kb 0
    if test "$kb" -ge 1024000
        printf "%.2f GiB" (math "$kb / 1048576")
    else if test "$kb" -ge 1000
        printf "%.1f MiB" (math "$kb / 1024")
    else if test "$kb" -gt 0
        printf "%d KiB" $kb
    else
        echo "0 B"
    end
end

function storage_clean --description "5-tier workstation storage reclamation engine with interactive TUI"
    set -l log_file "$HOME/Library/Logs/storage-cleanup.log"
    set -l dry_run 0
    set -l run_all 0
    set -l auto_yes 0
    set -l empty_trash 0
    set -l prune_volumes 0
    set -l force 0
    set -l trashed_kb 0

    # -------------------------------------------------------------------------
    # CLI Flag Parser
    # -------------------------------------------------------------------------
    for arg in $argv
        switch $arg
            case -h --help
                echo "Usage: storage_clean [OPTIONS]"
                echo
                echo "Options:"
                echo "  -d, --dry-run        Simulate cleanup and preview reclaimable storage"
                echo "  -a, --all            Comprehensive mode (stale builds >3d, mole, and unused images)"
                echo "  -y, --yes            Bypass interactive confirmation prompts for destructive flags"
                echo "      --empty-trash    Explicitly empty macOS ~/.Trash"
                echo "      --prune-volumes  Explicitly include unused Docker volumes (WARNING: deletes DB state)"
                echo "  -f, --force          Override concurrency lock"
                echo "  -h, --help           Show this help manual"
                echo
                echo "Operational Tiers:"
                echo "  [1/5] Workspaces & Builds     kondo age-gated (>14d) + validated SPM/Web build trashing"
                echo "  [2/5] Package Caches          Homebrew, Mise, Micromamba, Cargo, Pnpm, Bun, uv/pip"
                echo "  [3/5] Developer & OS Caches   Xcode DerivedData (active process guard) + Mole deep clean"
                echo "  [4/5] Containers              Docker unused images, networks, build cache (volumes safe)"
                echo "  [5/5] Recycling & Logs        Stale ~/Library/Logs + macOS Trash inspection"
                return 0
            case -d --dry-run
                set dry_run 1
            case -a --all
                set run_all 1
            case -y --yes
                set auto_yes 1
            case --empty-trash
                set empty_trash 1
            case --prune-volumes
                set prune_volumes 1
            case -f --force
                set force 1
            case "-*"
                # Handle combined short flags: -day, -dy, -ya, etc.
                if string match -qr '^-+[dDayYfF]+$' -- $arg
                    string match -q "*d*" -- $arg; and set dry_run 1
                    string match -q "*a*" -- $arg; and set run_all 1
                    string match -q "*y*" -- $arg; and set auto_yes 1
                    string match -q "*f*" -- $arg; and set force 1
                else
                    printf "\e[33m⚠  [storage_clean] Unknown flag: %s\e[0m\n" "$arg"
                end
        end
    end

    # Ensure shared TUI engine primitives are loaded
    if not functions -q __tui_spin_run
        test -f "$__fish_config_dir/functions/__tui_engine.fish"; and source "$__fish_config_dir/functions/__tui_engine.fish"
    end

    # -------------------------------------------------------------------------
    # Battery State Governor
    # -------------------------------------------------------------------------
    if __tui_is_on_battery
        if not test -t 1; and test $force -eq 0
            # Non-interactive background execution: defer to preserve battery
            set -l b_msg "[(date '+%Y-%m-%d %H:%M:%S')] Storage cleanup deferred: Workstation on battery power."
            echo "$b_msg" >> $log_file
            __tui_notify "Storage Reclamation" "Cleanup deferred while operating on battery power"
            return 0
        end
    end

    # -------------------------------------------------------------------------
    # Concurrency Mutex Lock
    # -------------------------------------------------------------------------
    set -l runtime_base "$TMPDIR"
    test -n "$runtime_base"; or set runtime_base "/tmp"
    set -l clean_base (string trim -r -c '/' "$runtime_base")
    set -l lock_dir "$clean_base/storage_clean_"(id -u)".lock"

    if not __tui_acquire_lock "$lock_dir" $force
        set -l active_pid (cat "$lock_dir/pid" 2>/dev/null)
        set -l pid_info ""
        test -n "$active_pid"; and set pid_info " (PID: $active_pid)"
        if test -t 1
            printf "  %b⚠%b  %bStorage Reclamation Lock Active%b\n" \
                $__tui_c_warn $__tui_c_reset $__tui_c_warn $__tui_c_reset
            printf "     ↳ %bConflict:%b  Another reclamation instance is currently executing%b%s%b\n" \
                $__tui_c_dim $__tui_c_reset $__tui_c_bold "$pid_info" $__tui_c_reset
            printf "     ↳ %bLock path:%b %s\n" \
                $__tui_c_dim $__tui_c_reset "$lock_dir"
            printf "     ↳ %bAction:%b    Use %b--force%b to override if this is a stale lock\n" \
                $__tui_c_dim $__tui_c_reset $__tui_c_item $__tui_c_reset
        else
            echo "[(date '+%Y-%m-%d %H:%M:%S')] Storage cleanup aborted: Concurrency lock $lock_dir active$pid_info." >> $log_file
        end
        return 1
    end

    mkdir -p (dirname "$log_file")
    set -l start_ts (date +%s)
    set -l date_str (date "+%Y-%m-%d %H:%M:%S")
    set -l mode_str "standard"
    test $dry_run -eq 1; and set mode_str "dry-run"
    test $run_all -eq 1; and set mode_str "comprehensive"

    # Capture initial APFS volume available space (KB)
    set -l df_start (df -k / | tail -n 1 | awk '{print $4}')

    # Log header
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> $log_file
    echo "[$date_str] Storage Reclamation Started (Mode: $mode_str)" >> $log_file
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> $log_file

    # Pipeline banner
    printf "🧹 %bWorkstation Storage Reclamation Pipeline%b\n" $__tui_c_title $__tui_c_reset
    printf "  %bMode:%b %b%s%b  ·  %bHost:%b %b%s%b\n" \
        $__tui_c_dim $__tui_c_reset $__tui_c_item "$mode_str" $__tui_c_reset \
        $__tui_c_dim $__tui_c_reset $__tui_c_dim (hostname -s) $__tui_c_reset
    __tui_divider

    # Battery notice if on battery in interactive mode
    if __tui_is_on_battery
        printf "  %b⚠%b  %bWorkstation is operating on battery power (discharging)%b\n\n" \
            $__tui_c_warn $__tui_c_reset $__tui_c_dim $__tui_c_reset
    end

    # -------------------------------------------------------------------------
    # Destructive Action Safety Governor (Interactive Confirmation)
    # -------------------------------------------------------------------------
    if test $auto_yes -eq 0 -a $dry_run -eq 0
        if test $prune_volumes -eq 1
            if test -t 0
                printf "  %b⚠%b  %bDestructive Action:%b Docker volumes containing persistent DB data will be purged.\n" \
                    $__tui_c_warn $__tui_c_reset $__tui_c_bold $__tui_c_reset
                printf "     Proceed with Docker volume prune? [y/N]: "
                read -l p_vol
                if not string match -qi "y*" -- "$p_vol"
                    set prune_volumes 0
                    printf "     ↳ %bDocker volume prune cancelled by user%b\n\n" $__tui_c_dim $__tui_c_reset
                end
            else
                set prune_volumes 0
                echo "[(date '+%Y-%m-%d %H:%M:%S')] Volume prune aborted: non-interactive shell without -y." >> $log_file
            end
        end

        if test $empty_trash -eq 1
            if test -t 0
                printf "  %b⚠%b  %bDestructive Action:%b macOS ~/.Trash will be permanently emptied.\n" \
                    $__tui_c_warn $__tui_c_reset $__tui_c_bold $__tui_c_reset
                printf "     Permanently empty Trash? [y/N]: "
                read -l p_trash
                if not string match -qi "y*" -- "$p_trash"
                    set empty_trash 0
                    printf "     ↳ %bTrash purging cancelled by user%b\n\n" $__tui_c_dim $__tui_c_reset
                end
            else
                set empty_trash 0
                echo "[(date '+%Y-%m-%d %H:%M:%S')] Empty trash aborted: non-interactive shell without -y." >> $log_file
            end
        end
    end

    # =========================================================================
    # [1/5] Project Workspaces & Build Artifacts
    # =========================================================================
    __tui_section "1/5" "Project Workspaces & Build Artifacts"

    set -l scan_paths
    test -d "$HOME/x/dev"; and set -a scan_paths "$HOME/x/dev"

    # Kondo recursive clean with age gating
    if test (count $scan_paths) -gt 0; and type -q kondo
        set -l kondo_age "14d"
        test $run_all -eq 1; and set kondo_age "3d"
        if test $dry_run -eq 1
            __tui_spin_run "[1/5]" "Simulating project build purge (kondo --older $kondo_age)" \
                "kondo -n -o $kondo_age $scan_paths" $log_file
        else
            __tui_spin_run "[1/5]" "Purging stale project build targets (kondo --older $kondo_age)" \
                "kondo -a -o $kondo_age $scan_paths" $log_file
        end
    else
        __tui_skip "[1/5]" "kondo not installed or scan paths not found; skipping kondo"
    end

    # Modern Web, Turborepo & SPM (.next, .turbo, .build, .nuxt, .svelte-kit, .astro) safe disposal
    set -l extra_clean_targets
    if test (count $scan_paths) -gt 0
        set extra_clean_targets (find $scan_paths -maxdepth 6 -type d \( \
            -name ".next" -o \
            -name ".turbo" -o \
            -name ".build" -o \
            -name ".nuxt" -o \
            -name ".svelte-kit" -o \
            -name ".astro" \
        \) 2>/dev/null)
    end

    set -l extra_count 0
    for target in $extra_clean_targets
        # Filter test suites, fixtures, and nested subpaths
        string match -qr '/tests?/' -- "$target"; and continue
        string match -qr '/fixtures?/' -- "$target"; and continue
        string match -qr '/node_modules/.+' -- "$target"; and continue

        # Contextual manifest & active workspace validation
        if not __storage_clean_is_safe_artifact "$target" "$run_all"
            continue
        end

        set -l disp_target (string replace "$HOME" "~" -- "$target")

        # Measure size before trashing
        set -l item_kb (du -sk "$target" 2>/dev/null | awk '{print $1}')
        test -n "$item_kb"; and set trashed_kb (math "$trashed_kb + $item_kb")

        if test $dry_run -eq 1
            __tui_checkbox 0 "$disp_target \e[90m(simulated)\e[0m"
        else
            trash "$target" >/dev/null 2>&1
            __tui_checkbox 1 "$disp_target"
            echo "Trashed build artifact: $target" >> $log_file
        end
        set extra_count (math $extra_count + 1)
    end

    if test $extra_count -gt 0
        __tui_sub_detail "success" "$extra_count validated build artifact(s) processed"
    else
        __tui_sub_detail "info" "No stale unreferenced build directories found"
    end

    # =========================================================================
    # [2/5] Package Managers & Toolchain Caches
    # =========================================================================
    __tui_section "2/5" "Package Managers & Toolchain Caches"

    # --- Homebrew ---
    if type -q brew
        if test $dry_run -eq 1
            __tui_spin_run "[2/5]" "Simulating Homebrew bottle cleanup (brew cleanup -n)" \
                "command brew cleanup -n" $log_file
        else
            __tui_spin_run "[2/5]" "Purging orphaned packages & old bottles (brew cleanup)" \
                "command brew autoremove && command brew cleanup --prune=all" $log_file
        end
    end

    # --- Mise ---
    if type -q mise
        if test $dry_run -eq 1
            __tui_checkbox 0 "Mise stale tools & plugins \e[90m(simulated)\e[0m"
        else
            __tui_spin_run "[2/5]" "Pruning stale Mise runtime versions & cache" \
                "command mise prune -y && command mise cache clean" $log_file
        end
    end

    # --- Micromamba / Mamba / Conda ---
    if type -q micromamba
        if test $dry_run -eq 1
            __tui_spin_run "[2/5]" "Simulating Micromamba cache clean" \
                "micromamba clean --all --yes --dry-run" $log_file
        else
            __tui_spin_run "[2/5]" "Purging Micromamba tarballs and index cache" \
                "micromamba clean --all --yes" $log_file
        end
    else if type -q mamba
        if test $dry_run -eq 1
            __tui_spin_run "[2/5]" "Simulating Mamba cache clean" \
                "mamba clean --all --yes --dry-run" $log_file
        else
            __tui_spin_run "[2/5]" "Purging Mamba tarballs and index cache" \
                "mamba clean --all --yes" $log_file
        end
    else if type -q conda
        if test $dry_run -eq 1
            __tui_spin_run "[2/5]" "Simulating Conda cache clean" \
                "conda clean --yes --dry-run --tarballs --index-cache" $log_file
        else
            __tui_spin_run "[2/5]" "Purging Conda package cache" \
                "conda clean --yes --index-cache --tarballs --logfiles" $log_file
        end
    end

    # --- Cargo crate cache ---
    if type -q cargo-cache
        if test $dry_run -eq 1
            __tui_spin_run "[2/5]" "Simulating Cargo crate cache clean" \
                "cargo-cache --autoclean --dry-run" $log_file
        else
            __tui_spin_run "[2/5]" "Purging stale Cargo git checkouts & sources" \
                "cargo-cache --autoclean" $log_file
        end
    end

    # --- Pnpm store ---
    if type -q pnpm
        if test $dry_run -eq 1
            __tui_checkbox 0 "Pnpm package store prune \e[90m(simulated)\e[0m"
        else
            __tui_spin_run "[2/5]" "Pruning unreferenced packages from Pnpm store" \
                "command pnpm store prune" $log_file
        end
    end

    # --- Bun ---
    if type -q bun; and test -d "$HOME/.cache/.bun" -o -d "$HOME/.bun/install/cache"
        if test $dry_run -eq 1
            __tui_checkbox 0 "Bun package cache \e[90m(simulated)\e[0m"
        else
            bun pm cache rm >/dev/null 2>&1
            __tui_checkbox 1 "Bun package cache"
            echo "Purged Bun package cache" >> $log_file
        end
    end

    # --- Python (uv / pip) ---
    if type -q uv
        if test $dry_run -eq 1
            __tui_checkbox 0 "UV package wheel cache \e[90m(simulated)\e[0m"
        else
            uv cache clean >/dev/null 2>&1
            __tui_checkbox 1 "UV package wheel cache"
            echo "Cleaned uv package wheel cache" >> $log_file
        end
    else if type -q pip
        if test $dry_run -eq 1
            __tui_checkbox 0 "Pip wheel cache \e[90m(simulated)\e[0m"
        else
            pip cache purge >/dev/null 2>&1
            __tui_checkbox 1 "Pip wheel cache"
            echo "Purged pip wheel cache" >> $log_file
        end
    end

    # =========================================================================
    # [3/5] macOS Developer & System Caches
    # =========================================================================
    __tui_section "3/5" "macOS Developer & System Caches"

    # --- Xcode DerivedData (with active IDE running guard) ---
    set -l xcode_derived "$HOME/Library/Developer/Xcode/DerivedData"
    if test -d "$xcode_derived"
        if pgrep -x Xcode >/dev/null 2>&1; or pgrep -x xcodebuild >/dev/null 2>&1
            __tui_skip "[3/5]" "Xcode actively running (DerivedData preserved to protect IDE indexing)"
        else
            set -l derived_items (command ls -A "$xcode_derived" 2>/dev/null)
            if test (count $derived_items) -gt 0
                set -l full_derived_items
                for it in $derived_items
                    set -a full_derived_items "$xcode_derived/$it"
                end

                set -l d_kb (du -sk $full_derived_items 2>/dev/null | awk '{sum+=$1} END {print sum}')
                test -n "$d_kb"; and set trashed_kb (math "$trashed_kb + $d_kb")

                if test $dry_run -eq 1
                    __tui_checkbox 0 "Xcode DerivedData ($xcode_derived) \e[90m(simulated)\e[0m"
                else
                    # Batch trash all items in a single call (Zero-Fork SLA)
                    trash $full_derived_items >/dev/null 2>&1
                    __tui_checkbox 1 "Xcode DerivedData → Trash"
                    echo "Moved Xcode DerivedData items to trash" >> $log_file
                end
            else
                __tui_checkbox 1 "Xcode DerivedData (already clean)"
            end
        end
    else
        __tui_skip "[3/5]" "Xcode DerivedData directory does not exist"
    end

    # --- Mole system & application cache optimizer ---
    if type -q mole; or type -q mo
        if test $run_all -eq 1
            if test $dry_run -eq 1
                __tui_spin_run "[3/5]" "Simulating macOS system cache cleanup (mo clean --dry-run)" \
                    "mo clean --dry-run" $log_file
            else
                # mo clean is an interactive TUI tool requiring Touch ID/sudo; notify user
                __tui_sub_detail "info" "Mole deep optimizer available: run 'mo clean' interactively for Touch ID/system caches"
            end
        else
            __tui_skip "[3/5]" "Mole deep cache purge deferred (run with -a/--all)"
        end
    end

    # =========================================================================
    # [4/5] Containers & Virtualization (Zero Database Volume Data Loss)
    # =========================================================================
    __tui_section "4/5" "Containers & Virtualization"

    if type -q docker; and docker info >/dev/null 2>&1
        if test $dry_run -eq 1
            __tui_spin_run "[4/5]" "Inspecting container storage footprint (docker system df)" \
                "docker system df" $log_file
        else if test $run_all -eq 1
            # Comprehensive mode: Prune all unused images, stopped containers, build cache (VOLUMES PROTECTED)
            __tui_spin_run "[4/5]" "Pruning containers, networks, images, and build cache (volumes preserved)" \
                "docker system prune -a -f" $log_file
        else
            # Standard mode: Prune stopped containers, unused networks, and dangling images
            __tui_spin_run "[4/5]" "Pruning stopped containers and dangling images" \
                "docker system prune -f" $log_file
        end

        # Dedicated Volume Safety Gate: Only prune volumes if explicitly requested & confirmed
        if test $prune_volumes -eq 1
            if test $dry_run -eq 1
                __tui_checkbox 0 "Docker persistent volumes prune \e[90m(simulated)\e[0m"
            else
                __tui_spin_run "[4/5]" "Purging unused Docker volumes (--prune-volumes confirmed)" \
                    "docker volume prune -f" $log_file
            end
        end
    else
        __tui_skip "[4/5]" "Docker daemon not active (skipping container purge)"
    end

    # =========================================================================
    # [5/5] Storage Recycling & Stale Logs (macOS Trash Protection)
    # =========================================================================
    __tui_section "5/5" "Storage Recycling & Stale Logs"

    # Prune user logs older than 14 days and larger than 0 bytes
    set -l stale_logs (find "$HOME/Library/Logs" -type f -name "*.log" -mtime +14 -size +0c 2>/dev/null)
    set -l stale_log_count (count $stale_logs)

    if test $stale_log_count -gt 0
        set -l logs_kb (du -sk $stale_logs 2>/dev/null | awk '{sum+=$1} END {print sum}')
        test -n "$logs_kb"; and set trashed_kb (math "$trashed_kb + $logs_kb")

        if test $dry_run -eq 1
            __tui_checkbox 0 "$stale_log_count stale logs (>14d) in ~/Library/Logs \e[90m(simulated)\e[0m"
        else
            # Batch trash in a single call instead of N individual forks
            trash $stale_logs >/dev/null 2>&1
            __tui_checkbox 1 "Purged $stale_log_count stale log files from ~/Library/Logs → Trash"
            echo "Purged $stale_log_count stale log files" >> $log_file
        end
    else
        __tui_checkbox 1 "No stale log files (>14d) detected in ~/Library/Logs"
    end

    # macOS Trash management: Never empty implicitly; require explicit --empty-trash
    set -l trash_items (command ls -A "$HOME/.Trash" 2>/dev/null | count)
    if test $trash_items -gt 0
        if test $empty_trash -eq 1
            if test $dry_run -eq 1
                __tui_checkbox 0 "macOS Trash ($trash_items items) \e[90m(simulated)\e[0m"
            else
                trash -e -y >/dev/null 2>&1
                __tui_checkbox 1 "Emptied macOS Trash ($trash_items items purged)"
                echo "Emptied macOS Trash ($trash_items items)" >> $log_file
            end
        else
            __tui_sub_detail "info" "macOS Trash contains $trash_items item(s). Run 'storage_clean --empty-trash' or 'trash -e' to purge."
        end
    else
        __tui_checkbox 1 "macOS Trash is empty"
    end

    # =========================================================================
    # Telemetry, Metrics & Notification (Dual-Circuit Telemetry)
    # =========================================================================
    set -l df_end (df -k / | tail -n 1 | awk '{print $4}')
    set -l freed_disk_kb (math "$df_end - $df_start")
    test $freed_disk_kb -lt 0; and set freed_disk_kb 0
    set -l elapsed_total (math (date +%s) - $start_ts)

    set -l freed_disk_str (__storage_clean_format_bytes $freed_disk_kb)
    set -l trashed_str (__storage_clean_format_bytes $trashed_kb)

    printf "\n"
    set -l status_line (printf "%b✔ Storage Reclamation Complete%b" $__tui_c_ok $__tui_c_reset)
    test $dry_run -eq 1; and set status_line (printf "%b✔ Storage Reclamation Simulation Complete%b" $__tui_c_ok $__tui_c_reset)

    set -l metrics_line
    if test $trashed_kb -gt 0 -a $empty_trash -eq 0
        set metrics_line (printf "%bDisk Reclaimed:%b %b%s%b  %b·%b  %bStaged to Trash:%b %b%s%b  %b·%b  %bDuration:%b %b%ds%b" \
            $__tui_c_dim $__tui_c_reset $__tui_c_ok "$freed_disk_str" $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_item "$trashed_str" $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_dim $elapsed_total $__tui_c_reset)
    else
        set metrics_line (printf "%bDisk Reclaimed:%b %b%s%b  %b·%b  %bDuration:%b %b%ds%b" \
            $__tui_c_dim $__tui_c_reset $__tui_c_ok "$freed_disk_str" $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset \
            $__tui_c_dim $__tui_c_reset $__tui_c_dim $elapsed_total $__tui_c_reset)
    end

    set -l log_line (printf "%bLog:%b %s" $__tui_c_dim $__tui_c_reset "$log_file")

    __tui_banner "$status_line" "$metrics_line" "$log_line"

    echo "Storage cleanup finished at $(date). Disk freed: $freed_disk_str, Staged to Trash: $trashed_str in {$elapsed_total}s" >> $log_file

    # Release Concurrency Mutex Lock
    __tui_release_lock "$lock_dir"

    # macOS User Notification
    if test $dry_run -eq 0
        if test $trashed_kb -gt 0 -a $empty_trash -eq 0
            __tui_notify "Storage Maintenance" "Cleanup finished. Disk: $freed_disk_str (Staged to Trash: $trashed_str) in {$elapsed_total}s"
        else
            __tui_notify "Storage Maintenance" "Workstation cleanup finished. Freed: $freed_disk_str in {$elapsed_total}s"
        end
    end
end
