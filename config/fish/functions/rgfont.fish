# ---
# schema: "mdd-node-v1"
# id: "functions/rgfont.fish"
# title: "Fuzzy Font Search Selector"
# layer: "Functions"
# responsibility: "Queries system fonts using fc-list, fuzzy-filters by name, and copies the selected font name to the system clipboard"
# dependencies: ["fc-list", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["system", "fzf", "utility"]
# ---

function rgfont --description "Search for fonts and copy selection to clipboard"
    if not command -sq fc-list
        echo "Error: 'fc-list' (fontconfig) is required but not installed." >&2
        return 1
    end
    if not command -sq fzf
        echo "Error: 'fzf' is required but not installed." >&2
        return 1
    end

    set -l font "$argv[1]"

    # Resolve portable copy command
    set -l copy_cmd pbcopy
    if not command -sq pbcopy
        if command -sq wl-copy
            set copy_cmd wl-copy
        else if command -sq xclip
            set copy_cmd "xclip -selection clipboard"
        else
            set copy_cmd cat
        end
    end

    set -l selected
    if test -n "$font"
        set selected (fc-list | rg -o '[^/]*$[^:]*' | awk -F':' '{print $1}' | grep -i -- "$font" | fzf --height 50% --reverse)
    else
        set selected (fc-list | rg -o '[^/]*$[^:]*' | awk -F':' '{print $1}' | fzf --height 50% --reverse)
    end

    if test -n "$selected"
        echo -n "$selected" | eval "$copy_cmd"
        echo "✅ Copied to clipboard: $selected"
    end
end

