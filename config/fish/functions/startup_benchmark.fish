# ---
# schema: "mdd-node-v1"
# id: "functions/startup_benchmark.fish"
# title: "Workstation Startup Latency Profiler & Zero-Fork SLA Benchmark Suite"
# layer: "Functions / Diagnostics"
# responsibility: "Audits workstation runtime topology (Single-Entrypoint Kernel, AOT Snapshot, Secretive SEP), extracts granular startup hotspots via fish --profile-startup, and executes statistical multi-mode hyperfine latency benchmarks against the Darwin baremetal baseline"
# dependencies: ["functions/__tui_engine.fish", "functions/__x_build_cache.fish"]
# backlinks: ["ZERO_FORK_WHITEPAPER.md", "MAP_OF_CONTENT.md", "README.md"]
# created_at: "2026-06-24"
# updated_at: "2026-10-16"
# last_commit: "pending"
# tags: ["profiling", "latency", "zero-fork-sla", "benchmarks", "telemetry", "aot", "hotspots", "principal"]
# ---

function startup_benchmark --description "Workstation Startup Latency Profiler & Zero-Fork SLA Benchmark Suite"
    # CLI Parameter Parsing
    set -l opt_quick 0
    set -l opt_bench_only 0
    set -l opt_rebuild 0
    set -l bench_runs 50
    set -l bench_warmup 10

    set -l i 1
    while test $i -le (count $argv)
        switch $argv[$i]
            case -h --help
                echo "Usage: startup_benchmark [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  -h, --help           Show this architectural manual"
                echo "  -q, --quick          Execute topology inspection and hotspot trace without hyperfine (<500ms)"
                echo "  -b, --bench-only     Skip topology inspection and execute multi-target hyperfine benchmark"
                echo "  -r, --runs <N>       Configure statistical benchmark iterations (default: 50)"
                echo "  -w, --warmup <N>     Configure benchmark warmup runs (default: 10)"
                echo "      --rebuild        Force asynchronous AOT cache compilation before profiling"
                return 0
            case -q --quick
                set opt_quick 1
            case -b --bench-only
                set opt_bench_only 1
            case --rebuild
                set opt_rebuild 1
            case -r --runs
                set i (math $i + 1)
                set bench_runs $argv[$i]
            case -w --warmup
                set i (math $i + 1)
                set bench_warmup $argv[$i]
        end
        set i (math $i + 1)
    end

    # Ensure shared TUI engine primitives are loaded
    if not functions -q __tui_banner
        test -f "$__fish_config_dir/functions/__tui_engine.fish"
        and source "$__fish_config_dir/functions/__tui_engine.fish"
    end

    if test $opt_rebuild -eq 1
        echo (set_color -o yellow)"[Rebuild] Recompiling AOT monolithic runtime cache..."(set_color normal)
        __x_build_cache
    end

    echo (set_color -o cyan) "==========================================================================" (set_color normal)
    echo (set_color -o white) " ⚡ Workstation Startup Latency Profiler & Zero-Fork SLA Suite" (set_color normal)
    echo (set_color -o cyan) "==========================================================================" (set_color normal)
    echo ""

    if test $opt_bench_only -eq 0
        # ━━━━━━━━━━━━━━ 1. Host Architecture & Environment Telemetry ━━━━━━━━━━━━━━
        echo (set_color -o yellow) "[1/4] Host Architecture & Environment Telemetry" (set_color normal)
        set -l os_ver (sw_vers -productVersion 2>/dev/null; or echo "macOS")
        set -l build_ver (sw_vers -buildVersion 2>/dev/null; or echo "unknown")
        set -l hw_arch (uname -m)
        set -l cpu_brand (sysctl -n machdep.cpu.brand_string 2>/dev/null; or echo "Apple Silicon")
        set -l tmux_state (if set -q TMUX; echo "Active ("(string split "," $TMUX)[1]")"; else; echo "None (Bare Metal)"; end)
        set -l term_state (if set -q GHOSTTY_RESOURCES_DIR; echo "Ghostty"; else if set -q KITTY_PID; echo "Kitty"; else; echo "Standard/Other"; end)

        echo "  OS Platform:     macOS $os_ver ($build_ver) — $hw_arch"
        echo "  Processor:       $cpu_brand"
        echo "  Fish Version:    $version"
        echo "  Terminal State:  $term_state"
        echo "  Multiplexer:     $tmux_state"
        echo ""

        # ━━━━━━━━━━━━━━ 2. Runtime Topology & Cache Subsystem Status ━━━━━━━━━━━━━━
        echo (set_color -o yellow) "[2/4] Runtime Topology & Cache Subsystem Status" (set_color normal)

        # A. Phase 0 Kernel
        set -l init_kernel "$__fish_config_dir/conf.d/init.fish"
        if test -f "$init_kernel"
            set -l k_lines (wc -l < "$init_kernel" | string trim)
            set -l k_size (ls -lh "$init_kernel" | awk '{print $5}')
            echo "  ✓ conf.d/init.fish:            " (set_color green) "Active" (set_color normal) " (Single Entrypoint, $k_lines lines, $k_size)"
        else
            echo "  ✗ conf.d/init.fish:            " (set_color red) "Missing" (set_color normal)
        end

        # B. AOT Monolithic Runtime Cache
        set -l aot_dir "$XDG_CACHE_HOME/fish/aot"
        set -l snapshot_file "$aot_dir/snapshot.fish"
        if test -f "$snapshot_file"
            set -l size (ls -lh "$snapshot_file" | awk '{print $5}')
            set -l mtime (date -r "$snapshot_file" "+%Y-%m-%d %H:%M:%S")
            echo "  ✓ aot/snapshot.fish:           " (set_color green) "Active" (set_color normal) " (Monolith: $size, Compiled: $mtime)"
        else
            echo "  ✗ aot/snapshot.fish:           " (set_color red) "Missing" (set_color normal) " (Run '__x_build_cache' to recompile)"
        end

        # C. Single-Flight Concurrency Mutex
        set -l lock_dir "$aot_dir/.build.lock"
        if test -d "$lock_dir"
            echo "  ⚠ aot/.build.lock:             " (set_color yellow) "Locked" (set_color normal) " (Compiler worker active or stale)"
        else
            echo "  ✓ aot/.build.lock:             " (set_color green) "Idle" (set_color normal) " (Single-Flight Mutex clear)"
        end

        # D. Cryptographic Identity Agent (Secretive SEP)
        set -l ssh_link "$HOME/.ssh/ssh_auth_sock"
        set -l secretive_sock "$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
        if test -S "$ssh_link"
            set -l target (readlink "$ssh_link" 2>/dev/null; or echo "$ssh_link")
            echo "  ✓ ssh_auth_sock router:        " (set_color green) "Valid" (set_color normal) " -> $target"
        else if test -S "$secretive_sock"
            echo "  ✓ Secretive SEP socket:        " (set_color green) "Available" (set_color normal) " -> $secretive_sock"
        else if set -q SSH_AUTH_SOCK; and test -S "$SSH_AUTH_SOCK"
            echo "  ✓ SSH_AUTH_SOCK forwarded:     " (set_color green) "Active" (set_color normal) " -> $SSH_AUTH_SOCK"
        else
            echo "  ✗ SSH agent socket:            " (set_color red) "Not resolved" (set_color normal)
        end

        # E. JIT Deferred Hydrators Inspection
        set -l hydrators __x_init_vars __x_init_abbrs __x_init_fzf __x_init_snapshot
        set -l all_hydrators_ok 1
        for h in $hydrators
            if not test -f "$__fish_config_dir/functions/$h.fish"
                set all_hydrators_ok 0
            end
        end
        if test $all_hydrators_ok -eq 1
            echo "  ✓ JIT Deferred Hydrators:      " (set_color green) "Available" (set_color normal) " (vars, abbrs, fzf, snapshot)"
        else
            echo "  ⚠ JIT Deferred Hydrators:      " (set_color yellow) "Partial" (set_color normal)
        end
        echo ""

        # ━━━━━━━━━━━━━━ 3. Startup Hotspot & Micro-Sourcing Telemetry ━━━━━━━━━━━━━━
        echo (set_color -o yellow) "[3/4] Startup Hotspot & Micro-Sourcing Telemetry (Top 12 Sourcing Events)" (set_color normal)
        set -l prof_file "/tmp/fish_profile_"(random)".prof"

        fish --profile-startup "$prof_file" -ic exit >/dev/null 2>&1

        if test -f "$prof_file"
            echo "   Exclusive (µs) │ Inclusive (µs) │ Sourcing Scope / Operation"
            echo "  ────────────────┼────────────────┼────────────────────────────────────────────"

            # Parse and print top events
            sort -nrk2 "$prof_file" | head -n 15 | while read -l excl incl depth name
                if not string match -qr '^[0-9]+$' "$excl"
                    continue
                end

                set -l clean_name (string replace "$HOME" "~" "$name")
                set -l full_name "$depth $clean_name"

                # Highlight conf.d/init.fish sourcing specifically
                if string match -q "*conf.d/init.fish*" "$clean_name"; or string match -q "*source \$file*" "$clean_name"
                    printf "     %s%8s µs%s │   %s%8s µs%s │ %s%s [KERNEL]%s\n" (set_color -o green) "$excl" (set_color normal) (set_color -o green) "$incl" (set_color normal) (set_color -o green) "$full_name" (set_color normal)
                else
                    printf "     %8s µs │   %8s µs │ %s\n" "$excl" "$incl" "$full_name"
                end
            end
            command rm -f "$prof_file"
        else
            echo "  Error: Unable to capture profile output."
        end
        echo ""
    end

    # ━━━━━━━━━━━━━━ 4. Multi-Target Statistical Latency Benchmark ━━━━━━━━━━━━━━
    if test $opt_quick -eq 0
        echo (set_color -o yellow) "[4/4] Multi-Target Statistical Latency Benchmark (Darwin Baremetal vs SLA)" (set_color normal)
        if type -q hyperfine
            echo "  Running statistical comparison: Baremetal Floor vs Non-Interactive vs Interactive"
            echo "  Iterations: $bench_runs runs (Warmup: $bench_warmup runs)"
            echo ""
            hyperfine --warmup $bench_warmup --runs $bench_runs \
                --command-name "Baremetal Floor  (fish --no-config -i)" "fish --no-config -i -c exit" \
                --command-name "Script Subshell  (fish -c exit)"        "fish -c exit" \
                --command-name "Interactive Boot (fish -i -c exit)"      "fish -i -c exit"
        else
            echo "  hyperfine not installed. Executing basic time inspection:"
            time fish -i -c exit
        end
        echo ""
    end

    echo (set_color -o cyan) "==========================================================================" (set_color normal)
end
