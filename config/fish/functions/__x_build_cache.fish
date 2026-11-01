# ---
# schema: "mdd-node-v1"
# id: "functions/__x_build_cache.fish"
# title: "AOT Snapshot Compiler with SWR Engine"
# layer: "Infrastructure / Compilation"
# responsibility: "Compiles external CLI initializers (Starship, Zoxide, xStory, FZF) into ~/.cache/fish/aot/snapshot.fish with SWR revalidation and Single-Flight Mutex"
# dependencies: []
# backlinks: ["conf.d/init.fish", "functions/__x_init_runtimes.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-19"
# tags: ["aot", "cache", "swr"]
# ---

# ==============================================================================
# INDUSTRIAL SWR & AOT COMPILATION ENGINE:
#
# 1. MONOLITHIC RUNTIME ARTIFACT:
#    Single file: $XDG_CACHE_HOME/fish/aot/snapshot.fish (~38 KB)
#    Contains full static definitions of Starship, Zoxide, Atuin (forkless UUID),
#    FZF widgets, and embedded SWR revalidation hook.
#
# 2. SINGLE-FLIGHT MUTEX (Cache Stampede & Dogpiling Guard):
#    Guarantees strictly one background compiler process across concurrent tabs/splits
#    using atomic directory locks ($XDG_CACHE_HOME/fish/aot/.build.lock).
#
# 3. DETACHED BACKGROUND SWR WORKER:
#    Disowns background compiler process (`&; disown`) to eliminate interactive shell
#    job warnings on terminal exit/exec.
#
# 4. ATOMIC APFS SWAP:
#    Outputs to an isolated PID file and executes atomic POSIX rename (`mv -f`).
# ==============================================================================

function __x_build_cache --description "AOT Monolithic Runtime Snapshot Compiler (SWR Engine)"
    set -l aot_dir "$XDG_CACHE_HOME/fish/aot"
    test -d "$aot_dir"; or command mkdir -p "$aot_dir"

    set -l snapshot_file "$aot_dir/snapshot.fish"
    set -l tmp_snapshot "$snapshot_file.$fish_pid"

    # Single-Flight Lock: Prevent concurrent background builds (Dogpiling Guard)
    set -l lock_dir "$aot_dir/.build.lock"
    if not command mkdir "$lock_dir" 2>/dev/null
        if test -f "$snapshot_file"
            # Background SWR race: snapshot exists, safe to skip build
            # Stale lock recovery (>30s)
            set -l lock_mtime (stat -f %m "$lock_dir" 2>/dev/null; or echo 0)
            set -l now (date +%s)
            if test (math "$now - $lock_mtime") -gt 30
                command rm -rf "$lock_dir"
                command mkdir "$lock_dir" 2>/dev/null; or return 0
            else
                return 0
            end
        else
            # Cold-boot barrier: snapshot is missing while another process builds it.
            # Zero-fork spin wait until the snapshot is committed or lock releases.
            set -l spin 0
            while not test -f "$snapshot_file"; and test -d "$lock_dir"; and test $spin -lt 10000
                set spin (math "$spin + 1")
            end
            if test -f "$snapshot_file"
                return 0
            end
            command mkdir "$lock_dir" 2>/dev/null; or return 0
        end
    end

    # Temporary files for parallel compilation
    set -l tmp_starship "$aot_dir/starship.tmp.$fish_pid"
    set -l tmp_zoxide "$aot_dir/zoxide.tmp.$fish_pid"
    set -l tmp_xstory "$aot_dir/xstory.tmp.$fish_pid"
    set -l tmp_fzf "$aot_dir/fzf.tmp.$fish_pid"

    set -l invalidation_checks ""

    # 1. Parallel Generation of Tool Payloads
    if set -l bin_path (command -s starship)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"$snapshot_file\""
        begin
            starship init fish --print-full-init >"$tmp_starship"
            echo "function starship_transient_prompt_func; starship module character; end" >>"$tmp_starship"
            echo "function starship_transient_rprompt_func; echo \"\"; end" >>"$tmp_starship"
            echo enable_transience >>"$tmp_starship"
            echo "function fish_mode_prompt; end" >>"$tmp_starship"
        end &
    end

    if set -l bin_path (command -s zoxide)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"$snapshot_file\""
        zoxide init fish >"$tmp_zoxide" &
    end

    # if set -l bin_path (command -s atuin)
    #     set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"$snapshot_file\""
    #     begin
    #         atuin init fish > "$tmp_atuin.raw"
    #         set -l atuin_content (string collect < "$tmp_atuin.raw")
    #         set -l atuin_array (string split \n $atuin_content)
    #         # Patch UUID generator to avoid process forks
    #         set -l native_uuid 'printf "%04x%04x-%04x-%04x-%04x-%04x%04x%04x" (random 0 65535) (random 0 65535) (random 0 65535) (random 16384 20479) (random 32768 49151) (random 0 65535) (random 0 65535) (random 0 65535)'
    #         set -l patched (string replace 'atuin uuid' "$native_uuid" $atuin_array)
    #         set patched (string match -v '*prepare-search-index*' $patched)
    #         printf "%s\n" $patched > "$tmp_atuin"
    #         command rm -f "$tmp_atuin.raw"
    #     end &
    # end

    # if set -l bin_path (command -s xstory)
    #     set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"$snapshot_file\""
    #     xstory init fish --print >"$tmp_xstory" 2>/dev/null &
    # end

    if set -l bin_path (command -s fzf)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"$snapshot_file\""
        fzf --fish >"$tmp_fzf" &
    end

    # Track Starship configuration changes
    set -l starship_toml "$XDG_CONFIG_HOME/starship/starship.toml"
    if test -f "$starship_toml"
        set invalidation_checks "$invalidation_checks; or test \"$starship_toml\" -nt \"$snapshot_file\""
    end

    # Track Fish single-entrypoint kernel changes
    set -l init_conf "$__fish_config_dir/conf.d/init.fish"
    if test -f "$init_conf"
        set invalidation_checks "$invalidation_checks; or test \"$init_conf\" -nt \"$snapshot_file\""
    end

    # Track Homebrew bin directory for package updates
    if test -d /opt/homebrew/bin
        set invalidation_checks "$invalidation_checks; or test \"/opt/homebrew/bin\" -nt \"$snapshot_file\""
    end

    # Barrier: Wait for all background compiler jobs to complete
    wait 2>/dev/null

    # 2. Atomic Stream Generation of Monolithic Snapshot
    set invalidation_checks (string replace -r "^; or " "" "$invalidation_checks")

    begin
        echo "# =============================================================================="
        echo "# AOT RUNTIME SNAPSHOT — DO NOT EDIT"
        echo "# Compiled by: __x_build_cache at "(date "+%Y-%m-%d %H:%M:%S")
        echo "# Target: $snapshot_file"
        echo "# =============================================================================="
        echo "set -g __x_runtimes_loaded 1"
        echo ""

        # Section 1: Starship Prompt Engine
        if test -f "$tmp_starship"
            echo "# --- Starship Prompt Engine ---"
            cat "$tmp_starship"
            command rm -f "$tmp_starship"
            echo ""
        end

        # Section 2: Zoxide Navigation Engine
        if test -f "$tmp_zoxide"
            echo "# --- Zoxide Navigation Engine ---"
            cat "$tmp_zoxide"
            command rm -f "$tmp_zoxide"
            echo ""
        end

        # Section 3: Atuin History Search Engine (Forkless UUID Patched)
        # if test -f "$tmp_atuin"
        #     echo "# --- Atuin History Search Engine ---"
        #     cat "$tmp_atuin"
        #     command rm -f "$tmp_atuin"
        #     echo ""
        # end

        # Section 3.1: xStory History Search Engine
        if test -f "$tmp_xstory"
            echo "# --- xStory History Search Engine ---"
            cat "$tmp_xstory"
            command rm -f "$tmp_xstory"
            echo ""
        end

        # Section 4: FZF Widget Integration
        if test -f "$tmp_fzf"
            echo "# --- FZF Widgets Integration ---"
            cat "$tmp_fzf"
            command rm -f "$tmp_fzf"
            echo ""
        end

        # Section 5: True SWR Background Revalidation Hook
        if test -n "$invalidation_checks"
            echo "# ------------------------------------------------------------------------------"
            echo "# SECTION 5: SWR BACKGROUND REVALIDATION HOOK"
            echo "# ------------------------------------------------------------------------------"
            echo "function __x_swr_check --on-event fish_prompt"
            echo "    functions -e __x_swr_check"
            echo "    if $invalidation_checks"
            echo "        command fish --private -c '__x_build_cache' &"
            echo "        disown \$last_pid 2>/dev/null"
            echo "    end"
            echo end
        end
    end >"$tmp_snapshot"

    # Atomic Commit via POSIX rename
    command mv -f "$tmp_snapshot" "$snapshot_file"

    # Release Single-Flight Mutex
    command rm -rf "$lock_dir"
end
