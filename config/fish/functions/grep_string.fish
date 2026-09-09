# ---
# schema: "mdd-node-v1"
# id: "functions/grep_string.fish"
# title: "Clipboard Content Searcher"
# layer: "Functions"
# responsibility: "Searches for clipboard string recursively in the current directory"
# dependencies: ["rg"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["search", "clipboard", "rg"]
# ---

function grep_string --description "Searches for clipboard string in the current directory"
    if not command -sq rg
        echo "Error: rg is required for grep_string" >&2
        return 1
    end
    set -l search_string ""
    if test (uname) = "Darwin"
        set search_string (pbpaste)
    else if command -sq wl-paste
        set search_string (wl-paste)
    else if command -sq xclip
        set search_string (xclip -o -selection clipboard)
    end

    if test -n "$search_string"
        echo "🔎 Searching for: $search_string..."
        rg --hidden --no-ignore --glob '!.git/*' -- "$search_string" 2>/dev/null
    else
        echo "Error: Clipboard is empty." >&2
        return 1
    end
end
