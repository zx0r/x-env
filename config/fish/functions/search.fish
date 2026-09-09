# ---
# schema: "mdd-node-v1"
# id: "functions/search.fish"
# title: "Text Search Shorthand"
# layer: "Functions"
# responsibility: "Search for text recursively in the current directory"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["search", "grep"]
# ---

function search --description "Search for text recursively in the current directory"
    if test -z "$argv[1]"
        echo "Usage: search <text>" >&2
        return 1
    end
    grep -rni -- "$argv[1]" . 2>/dev/null
end
