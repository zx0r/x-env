# ---
# schema: "mdd-node-v1"
# id: "functions/rg_find.fish"
# title: "Fuzzy Content Finder with rg"
# layer: "Functions"
# responsibility: "Search file contents with ripgrep and fzf"
# dependencies: ["rg", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["rg", "fzf", "search"]
# ---

function rg_find --description "Search file contents with ripgrep and fzf"
    if not command -sq rg; or not command -sq fzf
        echo "Error: rg and fzf are required" >&2
        return 1
    end
    if test -z "$argv[1]"
        echo "Usage: rg_find <search_string>" >&2
        return 1
    end
    set -l file (rg --files-with-matches --hidden --smart-case --glob '!.git/*' -- "$argv[1]" 2>/dev/null | fzf --preview "rg --context 5 --color=always --pretty -- '$argv[1]' {}")
    if test -n "$file"
        echo "📄 Found in: $file"
    end
end
