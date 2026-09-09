# ---
# schema: "mdd-node-v1"
# id: "functions/gitbranch.fish"
# title: "Fuzzy Git Branch Selector"
# layer: "Functions"
# responsibility: "Fuzzy selection and checkout of git branches"
# dependencies: ["git", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["git", "fzf", "branch"]
# ---

function gitbranch --description "Fuzzy selection and checkout of git branches"
    if not command -sq git; or not command -sq fzf
        echo "Error: git and fzf are required" >&2
        return 1
    end
    set -l branch (git branch --color=always | fzf --ansi | string trim | string replace -r '^\*\s+' '')
    if test -n "$branch"
        git checkout "$branch"
    end
end
