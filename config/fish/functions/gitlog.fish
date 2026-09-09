# ---
# schema: "mdd-node-v1"
# id: "functions/gitlog.fish"
# title: "Fuzzy Git History Browser"
# layer: "Functions"
# responsibility: "Fuzzy browser for git commit history in current repo"
# dependencies: ["git", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["git", "fzf", "log"]
# ---

function gitlog --description "Fuzzy browser for git commit history"
    if not command -sq git; or not command -sq fzf
        echo "Error: git and fzf are required" >&2
        return 1
    end
    git log --oneline --graph --decorate --all | fzf --preview "git show --color=always {1}"
end
