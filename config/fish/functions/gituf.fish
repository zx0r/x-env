# ---
# schema: "mdd-node-v1"
# id: "functions/gituf.fish"
# title: "Fuzzy Git Untracked File Selector"
# layer: "Functions"
# responsibility: "Fuzzy find and select untracked git files in current repo"
# dependencies: ["git", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["git", "fzf", "select"]
# ---

function gituf --description "Fuzzy find and select untracked git files"
    if not command -sq git; or not command -sq fzf
        echo "Error: git and fzf are required" >&2
        return 1
    end
    set -l file (git ls-files --others --exclude-standard | fzf --preview "bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || head -100 {}")
    if test -n "$file"
        echo "📄 Selected: $file"
    end
end
