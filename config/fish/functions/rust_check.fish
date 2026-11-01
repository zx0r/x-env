# ---
# schema: "mdd-node-v1"
# id: "functions/rust_check.fish"
# title: "Universal Principal+ Rust Quality Verification Engine"
# layer: "Functions"
# responsibility: "Executes enterprise-grade verification pipeline for ANY Rust crate or workspace"
# dependencies: ["cargo", "cargo-nextest", "cargo-deny", "cargo-machete", "cargo-llvm-cov"]
# ---

function rust_check --description "Universal Principal+ engineering quality verification suite for ANY Rust project"
    set -l options (fish_opt -s h -l help)
    set -a options (fish_opt -s m -l miri)
    set -a options (fish_opt -s c -l cov)
    set -a options (fish_opt -s q -l quick)
    set -a options (fish_opt -s a -l all)
    argparse $options -- $argv; or return 1

    if set -q _flag_help
        echo (set_color cyan --bold)"rust_check"(set_color normal)" - Universal Principal+ Rust Quality Verification"
        echo ""
        echo "Usage: rust_check [OPTIONS] [PATH]"
        echo ""
        echo "Options:"
        echo "  -h, --help     Show this help text"
        echo "  -q, --quick    Fast developer mode (format, clippy, unit tests only)"
        echo "  -m, --miri     Run Miri memory safety & Tree Borrows aliasing checks"
        echo "  -c, --cov      Run LLVM source-based code coverage report"
        echo "  -a, --all      Run full comprehensive suite (all gates + miri + coverage)"
        return 0
    end

    # 1. Dynamically locate Cargo.toml root (searches current dir and parents)
    set -l start_dir "$PWD"
    if test (count $argv) -gt 0; and test -d "$argv[1]"
        set start_dir (builtin realpath "$argv[1]")
    end

    set -l cargo_root "$start_dir"
    while not test -f "$cargo_root/Cargo.toml"
        if test "$cargo_root" = "/"
            set_color red --bold
            echo "✖ Error: No Cargo.toml found in $start_dir or any parent directory"
            set_color normal
            return 1
        end
        set cargo_root (path dirname "$cargo_root")
    end

    set -l original_dir "$PWD"
    builtin cd "$cargo_root"; or return 1

    # 2. Introspect project topology via cargo metadata
    set -l meta_json (cargo metadata --no-deps --format-version 1 2>/dev/null)
    set -l proj_name (echo "$meta_json" | jq -r '.packages[0].name // "unknown-crate"' 2>/dev/null)
    set -l is_workspace (test (echo "$meta_json" | jq '.workspace_members | length' 2>/dev/null) -gt 1; and echo 1; or echo 0)
    set -l has_deny (test -f "deny.toml"; and echo 1; or echo 0)
    set -l has_bins (echo "$meta_json" | jq -e '.packages[].targets[] | select(.kind[] == "bin")' >/dev/null 2>&1; and echo 1; or echo 0)
    set -l has_release_small (grep -q "profile.release-small" Cargo.toml 2>/dev/null; and echo 1; or echo 0)

    set -l total_gates 5
    not set -q _flag_quick; and test "$has_bins" = "1"; and set total_gates (math "$total_gates + 1")
    set -q _flag_all; and set total_gates (math "$total_gates + 2")
    not set -q _flag_all; and set -q _flag_miri; and set total_gates (math "$total_gates + 1")
    not set -q _flag_all; and set -q _flag_cov; and set total_gates (math "$total_gates + 1")

    set -l current_gate 1
    set -l pass_count 0
    set -l start_total (date +%s)

    function __rcheck_header --argument-names step total title
        set_color blue --bold
        printf "\n[%s/%s] " $step $total
        set_color yellow --bold
        printf "%s...\n" $title
        set_color normal
    end

    function __rcheck_pass --argument-names title elapsed
        set_color green --bold
        printf "  ✔ %s" $title
        set_color cyan
        printf " (%ss)\n" $elapsed
        set_color normal
    end

    function __rcheck_fail --argument-names title hint fix_cmd
        set_color red --bold
        printf "  ✖ %s FAILED\n" $title
        if test -n "$hint"
            set_color yellow
            printf "    Hint: %s\n" $hint
        end
        if test -n "$fix_cmd"
            set_color cyan
            printf "    Fix:  %s\n" $fix_cmd
        end
        set_color normal
    end

    # Preflight tool validation
    set -l base_tools "cargo:curl -sSf https://sh.rustup.rs | sh" "rustup:curl -sSf https://sh.rustup.rs | sh" "jq:brew install jq" "cargo-deny:brew install cargo-deny" "cargo-machete:cargo binstall cargo-machete" "cargo-nextest:brew install cargo-nextest"
    for tool_entry in $base_tools
        set -l parts (string split ":" $tool_entry)
        if not command -v $parts[1] >/dev/null 2>&1
            set_color red --bold
            printf "✖ Missing required tool '%s'\n" $parts[1]
            set_color cyan
            printf "  Install: %s\n" $parts[2]
            set_color normal
            builtin cd "$original_dir"; return 1
        end
    end

    # Preflight rustup components validation (active toolchain)
    set -l installed_comps (rustup component list --installed 2>/dev/null)
    set -l base_comps "rustfmt:rustup component add rustfmt" "clippy:rustup component add clippy"
    for comp_entry in $base_comps
        set -l parts (string split ":" $comp_entry)
        if not string match -q "$parts[1]*" $installed_comps
            set_color red --bold
            printf "✖ Missing required rustup component '%s'\n" $parts[1]
            set_color cyan
            printf "  Install: %s\n" $parts[2]
            set_color normal
            builtin cd "$original_dir"; return 1
        end
    end

    # Preflight checks for optional gates: Coverage
    if set -q _flag_cov; or set -q _flag_all
        if not command -v cargo-llvm-cov >/dev/null 2>&1
            set_color red --bold
            printf "✖ Missing required tool 'cargo-llvm-cov'\n"
            set_color cyan
            printf "  Install: brew install cargo-llvm-cov (or cargo binstall cargo-llvm-cov)\n"
            set_color normal
            builtin cd "$original_dir"; return 1
        end
        if not string match -q "llvm-tools*" $installed_comps
            set_color red --bold
            printf "✖ Missing required rustup component 'llvm-tools'\n"
            set_color cyan
            printf "  Install: rustup component add llvm-tools\n"
            set_color normal
            builtin cd "$original_dir"; return 1
        end
    end

    # Preflight checks for optional gates: Miri
    if set -q _flag_miri; or set -q _flag_all
        if not rustup toolchain list 2>/dev/null | string match -q "*nightly*"
            set_color red --bold
            printf "✖ Missing required toolchain 'nightly' for Miri\n"
            set_color cyan
            printf "  Install: rustup toolchain install nightly\n"
            set_color normal
            builtin cd "$original_dir"; return 1
        end
        set -l nightly_comps (rustup component list --toolchain nightly --installed 2>/dev/null)
        if not string match -q "miri*" $nightly_comps
            set_color red --bold
            printf "✖ Missing required rustup component 'miri' (nightly)\n"
            set_color cyan
            printf "  Install: rustup component add miri --toolchain nightly\n"
            set_color normal
            builtin cd "$original_dir"; return 1
        end
        if not string match -q "rust-src*" $nightly_comps
            set_color red --bold
            printf "✖ Missing required rustup component 'rust-src' (nightly)\n"
            set_color cyan
            printf "  Install: rustup component add rust-src --toolchain nightly\n"
            set_color normal
            builtin cd "$original_dir"; return 1
        end
    end

    set_color cyan --bold
    echo "================================================================================"
    printf "   UNIVERSAL RUST PRINCIPAL+ VERIFICATION: %s\n" (string upper "$proj_name")
    printf "   Root: %s\n" "$cargo_root"
    echo "================================================================================"
    set_color normal

    # Gate 1: Code Formatting Compliance
    set -l t0 (date +%s)
    __rcheck_header $current_gate $total_gates "Verifying Rustfmt Formatting"
    if cargo fmt --all -- --check
        set -l t1 (date +%s)
        __rcheck_pass "Rustfmt Code Style" (math "$t1 - $t0")
        set pass_count (math "$pass_count + 1")
    else
        __rcheck_fail "Rustfmt Code Style" "Formatting discrepancies found against rustfmt.toml" "cargo fmt --all"
        builtin cd "$original_dir"; return 1
    end
    set current_gate (math "$current_gate + 1")

    # Gate 2: Static Analysis (Clippy Workspace Strict)
    set -l t0 (date +%s)
    __rcheck_header $current_gate $total_gates "Running Clippy (Pedantic & Nursery Lints)"
    if cargo clippy --workspace --all-targets --all-features -- -D warnings
        set -l t1 (date +%s)
        __rcheck_pass "Clippy Static Analysis" (math "$t1 - $t0")
        set pass_count (math "$pass_count + 1")
    else
        __rcheck_fail "Clippy Static Analysis" "Linter warnings or errors detected" "cargo clippy --fix --allow-dirty"
        builtin cd "$original_dir"; return 1
    end
    set current_gate (math "$current_gate + 1")

    # Gate 3: Supply Chain Governance (cargo-deny)
    set -l t0 (date +%s)
    __rcheck_header $current_gate $total_gates "Auditing Supply Chain Security & Licenses"
    set -l deny_cmd "cargo deny check"
    test "$has_deny" = "0"; and set deny_cmd "cargo deny --all-features check advisories bans"
    if eval "$deny_cmd"
        set -l t1 (date +%s)
        __rcheck_pass "Supply Chain Audit (cargo-deny)" (math "$t1 - $t0")
        set pass_count (math "$pass_count + 1")
    else
        __rcheck_fail "Supply Chain Audit (cargo-deny)" "Vulnerabilities, bans or license violations found" "cargo deny check --all-features"
        builtin cd "$original_dir"; return 1
    end
    set current_gate (math "$current_gate + 1")

    # Gate 4: Unused Dependency Detection (cargo-machete)
    set -l t0 (date +%s)
    __rcheck_header $current_gate $total_gates "Scanning Unused Dependencies (cargo-machete)"
    if cargo machete
        set -l t1 (date +%s)
        __rcheck_pass "Dependency Hygiene (cargo-machete)" (math "$t1 - $t0")
        set pass_count (math "$pass_count + 1")
    else
        __rcheck_fail "Dependency Hygiene (cargo-machete)" "Unused crates found in Cargo.toml dependencies" "Remove flagged crates from Cargo.toml"
        builtin cd "$original_dir"; return 1
    end
    set current_gate (math "$current_gate + 1")

    # Gate 5: Process-Isolated Parallel Tests (cargo-nextest)
    set -l t0 (date +%s)
    __rcheck_header $current_gate $total_gates "Executing Tests (cargo-nextest)"
    if cargo nextest run --workspace --all-targets
        set -l t1 (date +%s)
        __rcheck_pass "Nextest Test Suite" (math "$t1 - $t0")
        set pass_count (math "$pass_count + 1")
    else
        __rcheck_fail "Nextest Test Suite" "One or more tests failed" "cargo test -- --nocapture"
        builtin cd "$original_dir"; return 1
    end
    set current_gate (math "$current_gate + 1")

    # Gate 6: Binary Footprint Verification (if binary targets exist and not --quick)
    if not set -q _flag_quick; and test "$has_bins" = "1"
        set -l t0 (date +%s)
        set -l build_profile "release"
        test "$has_release_small" = "1"; and set build_profile "release-small"

        __rcheck_header $current_gate $total_gates "Compiling Production Binary ($build_profile)"
        if cargo build --workspace --profile "$build_profile" >/dev/null 2>&1
            set -l t1 (date +%s)
            set -l bin_dir "target/$build_profile"
            test "$build_profile" = "release"; and set bin_dir "target/release"

            # Inspect all compiled binaries in output dir
            set -l bin_names (echo "$meta_json" | jq -r '.packages[].targets[] | select(.kind[] == "bin") | .name' 2>/dev/null)
            for bname in $bin_names
                set -l bpath "$bin_dir/$bname"
                if test -f "$bpath"
                    set -l bsize (stat -f%z "$bpath" 2>/dev/null; or stat -c%s "$bpath")
                    set -l bkb (math "$bsize / 1024")
                    set_color green --bold
                    printf "  ✔ Binary [%s]: %s KB (Profile: %s)\n" $bname $bkb $build_profile
                    set_color normal
                end
            end
            set pass_count (math "$pass_count + 1")
        else
            __rcheck_fail "Binary Compilation ($build_profile)" "Release compilation failed" "cargo build --profile $build_profile"
            builtin cd "$original_dir"; return 1
        end
        set current_gate (math "$current_gate + 1")
    end

    # Gate 7: Miri Tree Borrows (if --miri or --all)
    if set -q _flag_miri; or set -q _flag_all
        set -l t0 (date +%s)
        __rcheck_header $current_gate $total_gates "Verifying Memory Safety & Tree Borrows (Miri)"
        if env MIRIFLAGS="-Zmiri-disable-isolation" cargo +nightly miri test --workspace --lib
            set -l t1 (date +%s)
            __rcheck_pass "Miri Memory Safety & Aliasing" (math "$t1 - $t0")
            set pass_count (math "$pass_count + 1")
        else
            __rcheck_fail "Miri Memory Safety & Aliasing" "Memory model violations or undefined behavior detected" "cargo +nightly miri test --lib"
            builtin cd "$original_dir"; return 1
        end
        set current_gate (math "$current_gate + 1")
    end

    # Gate 8: LLVM Source Coverage (if --cov or --all)
    if set -q _flag_cov; or set -q _flag_all
        set -l t0 (date +%s)
        __rcheck_header $current_gate $total_gates "Calculating Source Coverage (cargo-llvm-cov)"
        if cargo llvm-cov --workspace --summary-only
            set -l t1 (date +%s)
            __rcheck_pass "Source Coverage Metrics" (math "$t1 - $t0")
            set pass_count (math "$pass_count + 1")
        else
            __rcheck_fail "Source Coverage Metrics" "Coverage calculation failed or cargo-llvm-cov missing" "brew install cargo-llvm-cov"
            builtin cd "$original_dir"; return 1
        end
        set current_gate (math "$current_gate + 1")
    end

    set -l end_total (date +%s)
    set -l total_elapsed (math "$end_total - $start_total")

    set_color cyan --bold
    echo "================================================================================"
    set_color green --bold
    printf "  ALL PRINCIPAL+ GATES PASSED: %s [%s/%s] in %ss\n" "$proj_name" $pass_count $total_gates $total_elapsed
    set_color cyan --bold
    echo "================================================================================"
    set_color normal

    builtin cd "$original_dir"
    return 0
end
