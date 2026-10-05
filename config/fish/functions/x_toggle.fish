# ---
# schema: "mdd-node-v1"
# id: "functions/x_toggle.fish"
# title: "Meta-Workspace Context Router (Execution <-> Brain)"
# layer: "Functions"
# responsibility: "Performs bidirectional isomorphic path translation between physical execution spaces (~/x) and cognitive knowledge spaces (~/x/brain)"
# dependencies: ["conf.d/00-xdg.fish"]
# backlinks: ["conf.d/20-abbr.fish"]
# created_at: "2026-10-05"
# updated_at: "2026-10-05"
# tags: ["workspace", "isomorphism", "navigation", "brain", "router", "zero-fork"]
# ---

function x_toggle -d "Toggle context between Execution (~/x) and Cognitive Brain (~/x/brain)"
    set -l current_dir (pwd -P 2>/dev/null; or pwd)
    set -l root_dir (path resolve "$X_ROOT" 2>/dev/null; or echo "$HOME/x")
    set -l brain_dir (path resolve "$X_BRAIN" 2>/dev/null; or echo "$HOME/x/brain")

    # Guard: Must be executed within Meta-Workspace (~/x)
    if not string match -q "$root_dir*" "$current_dir"
        printf "\e[31m✖ [x_toggle] Current directory is not within Meta-Workspace (~/x)\e[0m\n"
        return 1
    end

    set -l target_dir ""

    # Direction 1: Cognitive Brain -> Physical Execution
    if string match -q "$brain_dir*" "$current_dir"
        set -l rel_path (string replace "$brain_dir" "" "$current_dir")
        set -l rel_trimmed (string trim -l -c / "$rel_path")

        # Map numbered prefixes back to root domains
        if string match -qr '^01_dev(/.*|$)' "$rel_trimmed"
            set -l sub (string replace -r '^01_dev' 'dev' "$rel_trimmed")
            set target_dir "$root_dir/$sub"
        else if string match -qr '^02_agents(/.*|$)' "$rel_trimmed"
            set -l sub (string replace -r '^02_agents' 'agents' "$rel_trimmed")
            set target_dir "$root_dir/$sub"
        else if string match -qr '^03_config(/.*|$)' "$rel_trimmed"
            set -l sub (string replace -r '^03_config' 'config' "$rel_trimmed")
            set target_dir "$root_dir/$sub"
        else if test -z "$rel_trimmed"
            set target_dir "$root_dir"
        else
            set target_dir "$root_dir"
        end

    # Direction 2: Physical Execution -> Cognitive Brain
    else
        set -l rel_path (string replace "$root_dir" "" "$current_dir")
        set -l rel_trimmed (string trim -l -c / "$rel_path")

        # Map root domains to numbered brain spaces
        if string match -qr '^dev(/.*|$)' "$rel_trimmed"
            set -l sub (string replace -r '^dev' '01_dev' "$rel_trimmed")
            set target_dir "$brain_dir/$sub"
        else if string match -qr '^agents(/.*|$)' "$rel_trimmed"
            set -l sub (string replace -r '^agents' '02_agents' "$rel_trimmed")
            set target_dir "$brain_dir/$sub"
        else if string match -qr '^config(/.*|$)' "$rel_trimmed"
            set -l sub (string replace -r '^config' '03_config' "$rel_trimmed")
            set target_dir "$brain_dir/$sub"
        else if test -z "$rel_trimmed"
            set target_dir "$brain_dir"
        else
            set target_dir "$brain_dir/$rel_trimmed"
        end
    end

    # Lazy Provisioning: Ensure target directory exists
    if not test -d "$target_dir"
        command mkdir -p "$target_dir"
    end

    cd "$target_dir"
    printf "\e[38;5;141m[x_toggle]\e[0m %s\n" (string replace "$HOME" "~" "$target_dir")
end
