# ---
# schema: "mdd-node-v1"
# id: "functions/fzf_cd.fish"
# title: "Fuzzy Directory Navigator"
# layer: "Functions"
# responsibility: "Fuzzy searches directories recursively using fd and fzf, and changes the current working directory to the selection"
# dependencies: ["fd", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["navigation", "fzf", "utility"]
# ---

function fzf_cd --description "Fast directory navigation using fd and fzf"
    if not command -sq fd
        echo "Error: 'fd' is required but not installed." >&2
        return 1
    end
    if not command -sq fzf
        echo "Error: 'fzf' is required but not installed." >&2
        return 1
    end

    set -l dir (fd --type d --hidden --exclude .git 2>/dev/null | fzf --prompt="Select Directory: ")
    if test -n "$dir"
        builtin cd "$dir"
    end
end

