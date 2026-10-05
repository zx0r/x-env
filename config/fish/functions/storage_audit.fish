# ---
# schema: "mdd-node-v1"
# id: "functions/storage_audit.fish"
# title: "Workstation Storage Audit Dashboard"
# layer: "Functions"
# responsibility: "Performs comprehensive, read-only multi-tier inspection of workstation disk consumption across projects, runtimes, system caches, media, and trash with single-pass I/O telemetry and interactive TUI dashboard"
# dependencies: ["functions/__tui_engine.fish"]
# backlinks: ["conf.d/20-abbr.fish", "functions/storage_clean.fish"]
# created_at: "2026-10-03"
# updated_at: "2026-10-05"
# tags: ["storage", "audit", "disk", "diagnostics", "kondo", "dust", "macos", "tui", "spinner"]
# ---

# ==============================================================================
# WORKSTATION STORAGE AUDIT DASHBOARD (Read-Only, Interactive TUI)
# ------------------------------------------------------------------------------
# Principal-grade diagnostic inspection across 5 operational tiers:
# 1. Project Workspaces & Build Targets (kondo, .next, .turbo, .build, .git)
# 2. Package Managers & Toolchain Caches (Brew, Mamba, Cargo, Go, NPM, etc.)
# 3. AI Agents & Developer Tools (Antigravity, Codex, Neovim, Xcode)
# 4. Containers, Applications & System Caches (Docker, Safari, Telegram)
# 5. Media Captures, Storage Recycling & Logs (Screenshots, Movies, Trash)
#
# Architecture & Design Standards:
# - Single-pass I/O telemetry: Eliminates redundant recursive disk traversals
# - Zero double-counting: Deduplicates toolchain caches from global ~/Library/Caches
# - Transient animated spinner during discovery phase with automatic cleanup
# - Strict 3-column TUI grid alignment (name | size | path)
# - Guaranteed temporary file hygiene via unlinking on completion
# - Depends on __tui_engine.fish for all rendering primitives
# ==============================================================================

function storage_audit --description "Comprehensive read-only storage audit with interactive TUI dashboard"
    # Parse CLI flags
    for arg in $argv
        switch $arg
            case -h --help
                echo "Usage: storage_audit [OPTIONS]"
                echo
                echo "Options:"
                echo "  -h, --help    Show this help manual"
                echo
                echo "Operational Tiers:"
                echo "  [1/5] Project Workspaces & Build Targets (kondo, .build, .git)"
                echo "  [2/5] Package Managers & Toolchain Caches (brew, mamba, cargo, bun)"
                echo "  [3/5] AI Agents & Developer Tools (antigravity, codex, nvim, xcode)"
                echo "  [4/5] Containers, Applications & System Caches (docker, safari)"
                echo "  [5/5] Media Captures, Storage Recycling & Logs (trash, logs, media)"
                return 0
        end
    end

    # Ensure shared TUI engine primitives are loaded
    if not functions -q __tui_spin_run
        test -f "$__fish_config_dir/functions/__tui_engine.fish"; and source "$__fish_config_dir/functions/__tui_engine.fish"
    end

    # Resolve XDG and tool paths once
    set -l cache_home (set -q XDG_CACHE_HOME; and echo "$XDG_CACHE_HOME"; or echo "$HOME/.cache")
    set -l data_home (set -q XDG_DATA_HOME; and echo "$XDG_DATA_HOME"; or echo "$HOME/.local/share")
    set -l cargo_dir (set -q CARGO_HOME; and echo "$CARGO_HOME"; or echo "$HOME/.cargo")
    test -d "$data_home/.cargo"; and set cargo_dir "$data_home/.cargo"

    set -l brew_cache "$HOME/Library/Caches/Homebrew"
    if type -q brew
        set -l bc (brew --cache 2>/dev/null)
        test -d "$bc"; and set brew_cache "$bc"
    end

    # Authenticate existing project scan paths
    set -l scan_paths
    test -d "$HOME/x/dev"; and set -a scan_paths "$HOME/x/dev"
    test -d "$HOME/x/env"; and set -a scan_paths "$HOME/x/env"

    set -l start_ts (date +%s)
    set -l grand_total_kb 0
    set -l tier2_lib_caches_kb 0

    # Banner: Volume Capacity Overview
    set -l disk_info (df -h / | tail -n 1 | awk '{print $2, $3, $4, $5}')
    set -l vol_size (echo $disk_info | awk '{print $1}')
    set -l vol_used (echo $disk_info | awk '{print $2}')
    set -l vol_avail (echo $disk_info | awk '{print $3}')
    set -l vol_pct (echo $disk_info | awk '{print $4}')

    set -l host_str (hostname -s)
    set -l arch_str (uname -s)" "(uname -m)
    set -l meta_line (printf "\e[90mHost:\e[0m \e[38;5;153m%s\e[0m  ·  \e[90mArchitecture:\e[0m \e[38;5;153m%s\e[0m  ·  \e[90mVolume:\e[0m \e[38;5;153m/ (APFS)\e[0m" "$host_str" "$arch_str")
    set -l cap_line (printf "\e[90mUsed:\e[0m \e[1;37m%s\e[0m  ·  \e[90mFree:\e[0m \e[1;32m%s\e[0m  ·  \e[90mTotal:\e[0m \e[38;5;153m%s\e[0m  ·  \e[90mCapacity:\e[0m \e[1;33m%s\e[0m" "$vol_used" "$vol_avail" "$vol_size" "$vol_pct")

    __tui_banner \
        "Workstation Storage Audit Dashboard" \
        "$meta_line" \
        "$cap_line"

    # =========================================================================
    # [1/5] Project Workspaces & Build Targets
    # =========================================================================
    __tui_section "1/5" "Project Workspaces & Build Targets"

    set -l tier1_kb 0
    set -l tier1_items 0
    set -l reported_dirs
    set -l tier1_tmpfile (mktemp)

    # Transient scan phase: kondo + find with self-erasing spinner
    __tui_spin_transient "Scanning project build artifacts..." "
        # Kondo scan
        if type -q kondo; and test (count $scan_paths) -gt 0
            kondo -n $scan_paths 2>/dev/null > $tier1_tmpfile.kondo
        end

        # Secondary discovery for modern web/toolchain targets
        if test (count $scan_paths) -gt 0
            find $scan_paths -name '.git' -prune -o -type d \\( \
                -name '.next' -o \
                -name '.turbo' -o \
                -name '.build' -o \
                -name '.nuxt' -o \
                -name '.svelte-kit' -o \
                -name '.astro' -o \
                -name 'node_modules' \
            \\) -print 2>/dev/null > $tier1_tmpfile.find

            # Heavy git repos (> 250 MiB)
            find $scan_paths -name '.git' -type d -maxdepth 5 2>/dev/null > $tier1_tmpfile.git
        end
    "

    # Render kondo results (supports both terminal and middle tree branches)
    if test -f "$tier1_tmpfile.kondo"
        set -l curr_path ""
        for line in (cat "$tier1_tmpfile.kondo")
            if string match -qr 'Projects cleaned:' -- "$line"
                continue
            else if string match -qr '^\s*[└├]─' -- "$line"
                set -l raw_target (string replace -r '^\s*[└├]─\s*' '' -- "$line")
                set -l target_name (string match -r '^[^\s(]+' -- "$raw_target")
                set -l target_size (string match -r '\(([^)]+)\)' -- "$raw_target")[2]
                test -z "$target_size"; and set target_size (string match -r '\S+$' -- "$raw_target")

                if test -n "$curr_path"
                    set -l full_target (string replace "~" "$HOME" -- "$curr_path/$target_name")
                    test -d "$full_target"; or continue

                    set -l proj_name (basename "$curr_path")
                    set -l loc_desc "$curr_path/$target_name"
                    set -a reported_dirs "$curr_path/$target_name"
                    set -a reported_dirs "$full_target"

                    set -l kb (__tui_dir_size_kb "$full_target")
                    test -n "$kb"; and set tier1_kb (math $tier1_kb + $kb)
                    set tier1_items (math $tier1_items + 1)

                    __tui_print_row "$proj_name" "$target_size" "$loc_desc"
                end
            else if test -n "$line"
                set -l proj_path (string match -r '^\S+' -- "$line")
                set curr_path (string replace "$HOME" "~" -- "$proj_path")
            end
        end
    end

    # Render find results (modern web targets not covered by kondo)
    if test -f "$tier1_tmpfile.find"
        for target in (cat "$tier1_tmpfile.find")
            # Filter test suites, fixtures, and nested subpaths
            string match -qr '/tests?/' -- "$target"; and continue
            string match -qr '/fixtures?/' -- "$target"; and continue
            string match -qr '/node_modules/.+/node_modules' -- "$target"; and continue
            string match -qr '/\.next/.+' -- "$target"; and continue
            string match -qr '/\.turbo/.+' -- "$target"; and continue
            string match -qr '/\.build/.+' -- "$target"; and continue

            set -l disp_target (string replace "$HOME" "~" -- "$target")
            contains "$disp_target" $reported_dirs; and continue
            contains "$target" $reported_dirs; and continue
            set -a reported_dirs "$disp_target"
            set -a reported_dirs "$target"

            # Resolve clean project name (handles monorepos)
            set -l proj_dir (dirname "$target")
            set -l proj_name (basename "$proj_dir")
            set -l parent_dir (dirname "$proj_dir")
            if test (basename "$parent_dir") = "apps" -o (basename "$parent_dir") = "packages"
                set proj_name (basename (dirname "$parent_dir"))" ($proj_name)"
            end

            set -l loc_desc (string replace "$HOME" "~" -- "$proj_dir")"/"(basename "$target")
            set -l kb (__tui_dir_size_kb "$target")
            test -n "$kb" -a "$kb" -gt 0; or continue

            set -l sz (__tui_format_bytes $kb)
            set tier1_kb (math $tier1_kb + $kb)
            set tier1_items (math $tier1_items + 1)

            __tui_print_row "$proj_name" "$sz" "$loc_desc"
        end
    end

    # Tier 1 build targets subtotal
    if test $tier1_items -eq 0
        __tui_skip "" "No stale project build targets detected"
    else
        set grand_total_kb (math $grand_total_kb + $tier1_kb)
        set -l tier1_str (__tui_format_bytes $tier1_kb)
        printf "\n"
        __tui_print_row "⮑ Reclaimable ($tier1_items targets)" "$tier1_str" "" 1
    end

    # Heavy Git repositories (> 250 MiB, Protected Historical Telemetry)
    if test -f "$tier1_tmpfile.git"
        set -l has_git_header 0
        for gd in (cat "$tier1_tmpfile.git")
            set -l kb (__tui_dir_size_kb "$gd")
            test -n "$kb"; or continue
            if test $kb -ge 262144
                if test $has_git_header -eq 0
                    printf "\n  \e[90m↳ Protected Git Repositories (>250 MiB, non-removable):\e[0m\n"
                    set has_git_header 1
                end
                set -l proj_name (basename (dirname "$gd"))
                set -l disp_loc (string replace "$HOME" "~" -- "$gd")
                set -l sz (__tui_format_bytes $kb)
                __tui_print_row "$proj_name (git history)" "$sz" "$disp_loc" 0
            end
        end
    end

    # Guaranteed temporary file hygiene
    command rm -f "$tier1_tmpfile"* 2>/dev/null

    # =========================================================================
    # [2/5] Package Managers & Toolchain Caches
    # =========================================================================
    __tui_section "2/5" "Package Managers & Toolchain Caches"

    # Registry of all known package manager and toolchain cache directories
    set -l cache_defs \
        "Micromamba Package Store|$data_home/mamba/pkgs" \
        "Micromamba Virtual Envs|$data_home/mamba/envs" \
        "Rustup Toolchains & Docs|$HOME/.rustup" \
        "Cargo Crate & Git Storage|$cargo_dir" \
        "Mise Toolchain Installs|$data_home/mise/installs" \
        "Mise Toolchain Downloads|$data_home/mise/downloads" \
        "Mise Tool Cache|$data_home/mise/cache" \
        "PNPM Global Store|$data_home/pnpm/store" \
        "PNPM macOS Store|$HOME/Library/pnpm/store" \
        "NPM Global Package Cache|$HOME/.npm" \
        "Homebrew Bottles Cache|$brew_cache" \
        "Homebrew Caskroom Downloads|/opt/homebrew/Caskroom" \
        "Homebrew Global Node Modules|/opt/homebrew/lib/node_modules" \
        "Go Build Artifacts Cache|$HOME/Library/Caches/go-build" \
        "Go Module Dependencies|$HOME/go/pkg/mod" \
        "Bun Package Cache|$cache_home/.bun" \
        "Pip Wheel & HTTP Cache|$HOME/Library/Caches/pip" \
        "UV / UVX Package Wheel Cache|$cache_home/uv" \
        "Swift SPM Cloned Dependencies|$HOME/Library/Caches/org.swift.swiftpm" \
        "CocoaPods Download Cache|$HOME/Library/Caches/CocoaPods" \
        "RubyGems Cache|$HOME/.gem" \
        "Gradle Dependency Cache|$HOME/.gradle/caches"

    set -l tier2_kb 0
    set -l tier2_items 0
    set -l scanned_paths

    for entry in $cache_defs
        set -l parts (string split "|" -- $entry)
        set -l name $parts[1]
        set -l path $parts[2]

        test -d "$path"; or continue
        contains "$path" $scanned_paths; and continue
        set -a scanned_paths "$path"

        # Single-pass I/O: read KB once and format string representation
        set -l kb (__tui_dir_size_kb "$path")
        test -n "$kb" -a "$kb" -gt 0; or continue

        set -l sz (__tui_format_bytes $kb)
        set -l display_path (string replace "$HOME" "~" -- "$path")
        __tui_print_row "$name" "$sz" "$display_path"

        set tier2_kb (math $tier2_kb + $kb)
        set tier2_items (math $tier2_items + 1)

        # Track toolchain caches residing inside ~/Library/Caches for net accounting in Tier 4
        if string match -q "$HOME/Library/Caches/*" -- "$path"
            set tier2_lib_caches_kb (math $tier2_lib_caches_kb + $kb)
        end
    end

    if test $tier2_items -gt 0
        set grand_total_kb (math $grand_total_kb + $tier2_kb)
        set -l tier2_str (__tui_format_bytes $tier2_kb)
        printf "\n"
        __tui_print_row "⮑ Total ($tier2_items caches)" "$tier2_str" "" 1
    end

    # =========================================================================
    # [3/5] AI Agents & Developer Tools
    # =========================================================================
    __tui_section "3/5" "AI Agents & Developer Tools"

    set -l agent_defs \
        "Antigravity CLI Sessions|$HOME/.gemini/antigravity-cli" \
        "Antigravity IDE Agent State|$HOME/.gemini/antigravity-ide" \
        "Antigravity Platform Store|$HOME/.gemini/antigravity" \
        "Antigravity System Backups|$HOME/.gemini/antigravity-backup" \
        "Antigravity Global Storage|$HOME/.antigravity" \
        "Codex Agent Runtimes|$cache_home/codex-runtimes" \
        "Codex State & Sessions|$HOME/.codex" \
        "Headless MCP Browsers|$HOME/.linkedin-mcp/patchright-browsers" \
        "Claude Backup State|$HOME/.claude.BAK" \
        "Neovim Lazy Plugins|$data_home/nvim/lazy" \
        "Neovim Mason LSP Tools|$data_home/nvim/mason" \
        "Bob Neovim Release Store|$data_home/bob" \
        "Xcode DerivedData|$HOME/Library/Developer/Xcode/DerivedData"

    set -l tier3_kb 0
    set -l tier3_items 0
    set -l scanned_agents

    for entry in $agent_defs
        set -l parts (string split "|" -- $entry)
        set -l name $parts[1]
        set -l path $parts[2]

        test -d "$path"; or continue
        contains "$path" $scanned_agents; and continue
        set -a scanned_agents "$path"

        # Single-pass I/O: read KB once and format string representation
        set -l kb (__tui_dir_size_kb "$path")
        test -n "$kb" -a "$kb" -gt 0; or continue

        set -l sz (__tui_format_bytes $kb)
        set -l display_path (string replace "$HOME" "~" -- "$path")
        __tui_print_row "$name" "$sz" "$display_path"

        set tier3_kb (math $tier3_kb + $kb)
        set tier3_items (math $tier3_items + 1)
    end

    if test $tier3_items -gt 0
        set grand_total_kb (math $grand_total_kb + $tier3_kb)
        set -l tier3_str (__tui_format_bytes $tier3_kb)
        printf "\n"
        __tui_print_row "⮑ Total ($tier3_items stores)" "$tier3_str" "" 1
    end

    # =========================================================================
    # [4/5] Containers, Applications & System Caches
    # =========================================================================
    __tui_section "4/5" "Containers, Applications & System Caches"

    # Docker daemon telemetry (formatted cleanly into the 3-column TUI grid)
    if type -q docker; and docker info >/dev/null 2>&1
        set -l d_lines (docker system df --format "{{.Type}}|{{.Size}}|{{.Reclaimable}}" 2>/dev/null)
        if test (count $d_lines) -gt 0
            for row in $d_lines
                set -l r_parts (string split "|" -- $row)
                set -l d_type "Docker "$r_parts[1]
                set -l d_sz $r_parts[2]
                set -l d_rec $r_parts[3]
                __tui_print_row "$d_type" "$d_sz" "Reclaimable: $d_rec"
            end
        end
    else
        __tui_skip "" "Docker daemon not active (skipping daemon audit)"
    end

    # Heavy macOS Application Containers & System Caches
    set -l sys_defs \
        "Safari Browser Storage|$HOME/Library/Containers/com.apple.Safari" \
        "Docker Desktop Container Store|$HOME/Library/Containers/com.docker.docker" \
        "VSCodium Storage|$HOME/Library/Application Support/VSCodium" \
        "Kimi Desktop Storage|$HOME/Library/Application Support/kimi-desktop" \
        "Telegram Media Storage|$HOME/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram" \
        "Spotlight Search Index|$HOME/Library/Metadata/CoreSpotlight" \
        "macOS User & App Caches|$HOME/Library/Caches"

    set -l tier4_kb 0
    set -l tier4_items 0
    set -l scanned_sys

    for entry in $sys_defs
        set -l parts (string split "|" -- $entry)
        set -l name $parts[1]
        set -l path $parts[2]

        test -d "$path"; or continue
        contains "$path" $scanned_sys; and continue
        set -a scanned_sys "$path"

        # Single-pass I/O: read KB once
        set -l kb (__tui_dir_size_kb "$path")
        test -n "$kb" -a "$kb" -gt 0; or continue

        set -l display_path (string replace "$HOME" "~" -- "$path")

        # Zero Double-Counting: Deduplicate ~/Library/Caches against Tier 2 toolchains
        if test "$path" = "$HOME/Library/Caches" -a $tier2_lib_caches_kb -gt 0
            set -l net_kb (math "$kb - $tier2_lib_caches_kb")
            test $net_kb -lt 0; and set net_kb 0
            set kb $net_kb
            set display_path "$display_path (net of toolchains)"
        end

        set -l sz (__tui_format_bytes $kb)
        __tui_print_row "$name" "$sz" "$display_path"

        set tier4_kb (math $tier4_kb + $kb)
        set tier4_items (math $tier4_items + 1)
    end

    if test $tier4_items -gt 0
        set grand_total_kb (math $grand_total_kb + $tier4_kb)
        set -l tier4_str (__tui_format_bytes $tier4_kb)
        printf "\n"
        __tui_print_row "⮑ Total ($tier4_items containers)" "$tier4_str" "" 1
    end

    # =========================================================================
    # [5/5] Media Captures, Trash & Logs
    # =========================================================================
    __tui_section "5/5" "Media Captures, Trash & Logs"

    set -l tier5_kb 0

    # macOS Screenshots
    set -l sc_loc (defaults read com.apple.screencapture location 2>/dev/null)
    test -z "$sc_loc"; and set sc_loc "$HOME/Pictures/Screenshots"
    if test -d "$sc_loc"
        set -l kb (__tui_dir_size_kb "$sc_loc")
        if test -n "$kb" -a "$kb" -gt 0
            set -l sc_sz (__tui_format_bytes $kb)
            set -l sc_cnt (find "$sc_loc" -type f 2>/dev/null | count)
            set -l disp_sc (string replace "$HOME" "~" -- "$sc_loc")
            __tui_print_row "Screenshots" "$sc_sz" "$disp_sc ($sc_cnt items)"
            set tier5_kb (math $tier5_kb + $kb)
        end
    end

    # Screen Recordings & Movies
    if test -d "$HOME/Movies"
        set -l kb (__tui_dir_size_kb "$HOME/Movies")
        if test -n "$kb" -a "$kb" -gt 0
            set -l mov_sz (__tui_format_bytes $kb)
            set -l mov_cnt (find "$HOME/Movies" -type f 2>/dev/null | count)
            __tui_print_row "Screen Recordings / Movies" "$mov_sz" "~/Movies ($mov_cnt items)"
            set tier5_kb (math $tier5_kb + $kb)
        end
    end

    # User Downloads
    if test -d "$HOME/Downloads"
        set -l kb (__tui_dir_size_kb "$HOME/Downloads")
        if test -n "$kb" -a "$kb" -gt 0
            set -l dl_sz (__tui_format_bytes $kb)
            set -l dl_cnt (find "$HOME/Downloads" -type f 2>/dev/null | count)
            __tui_print_row "User Downloads" "$dl_sz" "~/Downloads ($dl_cnt items)"
            set tier5_kb (math $tier5_kb + $kb)
        end
    end

    # macOS Trash
    set -l trash_dir "$HOME/.Trash"
    if test -d "$trash_dir"
        set -l t_items (command ls -A "$trash_dir" 2>/dev/null | count)
        set -l kb (__tui_dir_size_kb "$trash_dir")
        test -z "$kb"; and set kb 0
        set -l t_size (__tui_format_bytes $kb)
        __tui_print_row "macOS Trash" "$t_size" "~/.Trash ($t_items items)"
        set tier5_kb (math $tier5_kb + $kb)
    end

    # User Logs
    set -l logs_dir "$HOME/Library/Logs"
    if test -d "$logs_dir"
        set -l kb (__tui_dir_size_kb "$logs_dir")
        test -z "$kb"; and set kb 0
        set -l l_size (__tui_format_bytes $kb)
        __tui_print_row "User Logs" "$l_size" "~/Library/Logs"
        set tier5_kb (math $tier5_kb + $kb)
    end

    if test $tier5_kb -gt 0
        set grand_total_kb (math $grand_total_kb + $tier5_kb)
        set -l tier5_str (__tui_format_bytes $tier5_kb)
        printf "\n"
        __tui_print_row "⮑ Total (media & recycling)" "$tier5_str" "" 1
    end

    # =========================================================================
    # Grand Summary Footer
    # =========================================================================
    set -l elapsed_total (math (date +%s) - $start_ts)
    set -l grand_total_str (__tui_format_bytes $grand_total_kb)

    printf "\n"
    set -l summary_line (printf "\e[1;32m✔ Audit Complete\e[0m  ·  \e[90mScanned footprint:\e[0m \e[1;33m%s\e[0m \e[90m(in %ds)\e[0m" "$grand_total_str" $elapsed_total)
    set -l next_line (printf "\e[90mNext:\e[0m Run '\e[36mstorage_clean\e[0m' or '\e[36mstorage_clean -d\e[0m' to safely reclaim storage")

    __tui_banner \
        "$summary_line" \
        "$next_line"
end
