# ---
# schema: "mdd-node-v1"
# id: "functions/fzf_find.fish"
# title: "Fuzzy File Finder"
# layer: "Functions"
# responsibility: "Fuzzy find files in current directory with preview"
# dependencies: ["fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["fzf", "find"]
# ---

function fzf_find --description "Fuzzy find files in current directory with preview"
    if not command -sq fzf
        echo "Error: fzf is not installed" >&2
        return 1
    end
    set -l file (fzf --preview 'bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || head -100 {}')
    if test -n "$file"
        echo "📄 Selected: $file"
    end
end
