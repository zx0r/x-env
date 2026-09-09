# ---
# schema: "mdd-node-v1"
# id: "functions/ff.fish"
# title: "Name-Based File Finder Shorthand"
# layer: "Functions"
# responsibility: "Fast recursive search for files by name"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["search", "find"]
# ---

function ff --description "Fast recursive search for files by name"
    if test -z "$argv[1]"
        echo "Usage: ff <pattern>" >&2
        return 1
    end
    find . -iname "*$argv[1]*" 2>/dev/null
end
