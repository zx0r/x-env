# ---
# schema: "mdd-node-v1"
# id: "functions/lazygit.fish"
# title: "Smart Lazygit Launcher"
# layer: "Functions"
# responsibility: "Navigates to the git root directory and runs lazygit"
# dependencies: ["git", "lazygit"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-10-09"
# last_commit: ""
# tags: ["git", "utility"]
# ---

function lazygit --description "Navigate to Git root and launch lazygit"
    if not command -sq lazygit
        echo "Error: 'lazygit' is required but not installed." >&2
        return 1
    end

    # Pass-through if specific arguments or flags are passed (e.g. -p, --version)
    if test (count $argv) -gt 0
        command lazygit $argv
        return $status
    end

    # Ensure we are inside a Git repository before launching
    set -l repo (command git rev-parse --show-toplevel 2>/dev/null)
    if test -n "$repo"
        builtin cd "$repo"
        command lazygit
    else
        echo "Error: Not a Git repository." >&2
        return 1
    end
end
