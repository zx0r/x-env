# ---
# schema: "mdd-node-v1"
# id: "functions/fd_find.fish"
# title: "Fuzzy File Finder with fd"
# layer: "Functions"
# responsibility: "Search files with fd and fzf"
# dependencies: ["fd", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["fd", "fzf", "find"]
# ---

function fd_find --description "Search files with fd and fzf"
    if not command -sq fd; or not command -sq fzf
        echo "Error: fd and fzf are required" >&2
        return 1
    end
    set -l query "$argv"
    set -l file (fd --type f --hidden --exclude .git "$query" 2>/dev/null | fzf --preview 'bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || head -100 {}')
    if test -n "$file"
        echo "📄 Selected: $file"
    end
end
