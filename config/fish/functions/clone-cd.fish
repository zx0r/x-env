# ---
# schema: "mdd-node-v1"
# id: "functions/clone-cd.fish"
# title: "Git Clone & Navigate"
# layer: "Functions"
# responsibility: "Clones a git repository with depth=1 and changes the shell directory into it"
# dependencies: ["git"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["git", "navigation"]
# ---

function clone-cd --description "Clone a Git repository and cd into it"
    if test -z "$argv[1]"
        echo "Usage: clone-cd <url> [destination]" >&2
        return 1
    end

    set -l url $argv[1]
    set -l destination $argv[2]

    if test -z "$destination"
        # Parse repository name from the URL
        set -l base (basename -- "$url")
        set destination (string replace -r '\.git$' '' -- "$base")
    end

    if test -e "$destination"
        echo "Path exists: $destination. Attempting pull..."
        if test -d "$destination/.git"
            builtin cd "$destination"
            git pull
        else
            echo "Error: '$destination' exists but is not a Git repository." >&2
            return 1
        end
        return
    end

    git clone --depth=1 -- "$url" "$destination"
    if test $status -eq 0
        builtin cd "$destination"
    else
        echo "Error: Failed to clone repository." >&2
        return 1
    end
end

