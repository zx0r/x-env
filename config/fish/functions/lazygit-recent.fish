# ---
# schema: "mdd-node-v1"
# id: "functions/lazygit-recent.fish"
# title: "Fuzzy Git Repository Launcher"
# layer: "Functions"
# responsibility: "Fuzzy finds a Git repository from managed workspaces or directories and opens lazygit inside it"
# dependencies: ["lazygit", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["git", "fzf", "navigation", "x-workspace"]
# ---

function lazygit-recent --description "Fuzzy find a Git repo and open lazygit"
    if not command -sq lazygit
        echo "Error: 'lazygit' is required but not installed." >&2
        return 1
    end
    if not command -sq fzf
        echo "Error: 'fzf' is required but not installed." >&2
        return 1
    end

    set -l repos

    # 1. Use ghq if available
    if command -sq ghq
        set repos (ghq list -p)
    end

    # 2. Add directories from managed engineering workspace ($X_DEV)
    set -l projects_dir (set -q X_DEV; and echo "$X_DEV"; or echo "$HOME/x/dev")

    if test -d "$projects_dir"
        # Find .git directories up to depth 3 in projects directory (very fast)
        set -l fd_repos
        if command -sq fd
            set fd_repos (fd -H -t d -d 3 '^\.git$' "$projects_dir" 2>/dev/null | string replace -r '/\.git/?$' '')
        else
            set fd_repos (find "$projects_dir" -maxdepth 3 -type d -name ".git" 2>/dev/null | sed 's|/\.git||')
        end
        set repos $repos $fd_repos
    end

    # Filter out empty entries and unique the array
    set -l unique_repos (string match -r '\S+' -- $repos | sort -u)

    if test (count $unique_repos) -eq 0
        echo "No Git repositories found in managed directories ($projects_dir)." >&2
        return 1
    end

    set -l selected (printf "%s\n" $unique_repos | fzf --prompt "Select a Git repo: ")
    if test -n "$selected"; and test -d "$selected"
        builtin cd "$selected"
        lazygit
    else
        echo "No repository selected."
    end
end
