# ---
# schema: "mdd-node-v1"
# id: "functions/gitf.fish"
# title: "Fuzzy Git Tracked File Selector"
# layer: "Functions"
# responsibility: "Fuzzy find and select git-tracked files in current repo"
# dependencies: ["git", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["git", "fzf", "select"]
# ---

function gitf --description "Fuzzy find and select git-tracked files"
    if not command -sq git; or not command -sq fzf
        echo "Error: git and fzf are required" >&2
        return 1
    end
    set -l file (git ls-files | fzf --preview "bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || head -100 {}")
    if test -n "$file"
        echo "📄 Selected: $file"
    end
end
