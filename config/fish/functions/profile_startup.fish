# ---
# schema: "mdd-node-v1"
# id: "functions/profile_startup.fish"
# title: "Profile Startup"
# layer: "Functions"
# responsibility: "Profiles fish shell startup latency, lists hotspots, and runs benchmarks"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-07-12"
# last_commit: "pending"
# tags: ["profiling", "performance", "benchmark"]
# ---

function profile_startup -d "Profiles fish shell startup latency, lists hotspots, and runs benchmarks"
    echo (set_color -o blue)"=========================================================================="
    echo " ⚡ Fish Shell Startup Latency Profiler & Benchmark Suite"
    echo "=========================================================================="(set_color normal)
    echo ""

    # 1. Environment Inspection
    echo (set_color -o yellow)"[1/4] Environment Information"(set_color normal)
    echo "  OS Version:     "(sw_vers -productVersion 2>/dev/null; or echo "macOS")" ("(uname -m)")"
    echo "  Fish Version:   "$version
    echo "  Multiplexer:    "(if set -q TMUX; echo "tmux ("$TMUX")"; else; echo "None"; end)
    echo "  Terminal:       "(if set -q KITTY_PID; echo "Kitty"; else; echo "Standard/Other"; end)
    echo ""

    # 2. Cache & Security Infrastructure Status
    echo (set_color -o yellow)"[2/4] Cache & Security Topology Status"(set_color normal)
    set -l cache_dir "$XDG_CACHE_HOME/fish/static_init"
    if test -d "$cache_dir"
        set -l cache_files atuin.fish fzf.fish starship.fish zoxide.fish
        for file in $cache_files
            set -l path "$cache_dir/$file"
            if test -f "$path"
                set -l size (ls -lh "$path" | awk '{print $5}')
                set -l mtime (date -r "$path" "+%Y-%m-%d %H:%M:%S")
                echo "  ✓ $file: "(set_color green)"Active"(set_color normal)" (Size: $size, Compiled: $mtime)"
            else
                echo "  ✗ $file: "(set_color red)"Missing"(set_color normal)
            end
        end
    else
        echo "  ✗ Cache Directory: "(set_color red)"Not Found"(set_color normal)" (Run 'refresh_shell_cache' to bootstrap)"
    end

    # Check Secure SSH Infrastructure
    set -l ssh_env "$HOME/.ssh/agent_env"
    if test -f "$ssh_env"
        # Check if permissions are locked down (only readable by user)
        set -l perms (stat -f "%Sp" "$ssh_env" 2>/dev/null; or echo "unknown")
        set -l size (ls -lh "$ssh_env" | awk '{print $5}')
        if string match -q "*-rw-------*" "$perms"
            echo "  ✓ agent_env: "(set_color green)"Secure"(set_color normal)" (Size: $size, Perms: $perms)"
        else
            echo "  ⚠ agent_env: "(set_color yellow)"Insecure Permissions"(set_color normal)" (Perms: $perms)"
        end
    else
        echo "  - agent_env: "(set_color brblack)"Inactive (Launchd socket inherited, no local daemon required)"(set_color normal)
    end

    set -l ssh_link "$HOME/.ssh/ssh_auth_sock"
    if test -L "$ssh_link"
        set -l target (readlink "$ssh_link")
        if test -S "$target"
            echo "  ✓ ssh_auth_sock symlink: "(set_color green)"Valid"(set_color normal)" -> $target"
        else
            echo "  ⚠ ssh_auth_sock symlink: "(set_color red)"Broken target"(set_color normal)" -> $target"
        end
    else
        echo "  ✗ ssh_auth_sock symlink: "(set_color red)"Not created"(set_color normal)
    end
    echo ""

    # 3. Hotspot Profiling (fish --profile-startup)
    echo (set_color -o yellow)"[3/4] Startup Hotspot Analysis (Top 10 Slowest Operations)"(set_color normal)
    set -l prof_file "/tmp/fish_profile_"(random)".prof"
    
    # Run fish with profiling enabled
    fish --profile-startup "$prof_file" -ic exit >/dev/null 2>&1
    
    if test -f "$prof_file"
        # Parse, sort, and print top 10 slow events.
        echo "   Exclusive (ms) │ Inclusive (ms) │ Source File / Operation"
        echo "  ────────────────┼────────────────┼────────────────────────────────────────"
        sort -nrk2 "$prof_file" | head -n 15 | while read -l excl incl depth name
            # Skip header or empty lines
            if not string match -qr '^[0-9]+$' "$excl"
                continue
            end
            # Convert microsec to millisec
            set -l excl_ms (math -s 2 "$excl / 1000")
            set -l incl_ms (math -s 2 "$incl / 1000")
            # Format filename to be shorter (replace absolute path with ~/ or relative)
            set -l clean_name (string replace "$HOME" "~" "$name")
            set -l full_name "$depth $clean_name"
            printf "     %8s     │    %8s    │ %s\n" "$excl_ms" "$incl_ms" "$full_name"
        end
        rm -f "$prof_file"
    else
        echo "  Error: Failed to generate startup profile file."
    end
    echo ""

    # 4. Hyperfine Benchmark Suite
    echo (set_color -o yellow)"[4/4] Execution Performance Benchmark (Cold Launch)"(set_color normal)
    if type -q hyperfine
        echo "  Executing hyperfine benchmark (10 warmup, 50 runs)..."
        echo ""
        hyperfine --warmup 10 --runs 50 "fish -i -c exit"
    else
        echo "  hyperfine utility not found."
        echo "  To run benchmark: brew install hyperfine"
        echo "  Running fallback test (time fish -i -c exit)..."
        echo ""
        time fish -i -c exit
    end
    echo ""
    echo (set_color -o blue)"=========================================================================="(set_color normal)
end
