# ---
# schema: "mdd-node-v1"
# id: "functions/fo.fish"
# title: "Fuzzy File Editor Launcher"
# layer: "Functions"
# responsibility: "Fuzzy find files and open them in the current editor"
# dependencies: ["fd", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["fd", "fzf", "editor"]
# ---

function fo --description "Fuzzy find and open files in EDITOR"
    if not command -sq fd; or not command -sq fzf
        echo "Error: fd and fzf are required" >&2
        return 1
    end
    set -l file (fd --type f --hidden --exclude .git 2>/dev/null | fzf --preview 'bat --style=numbers --color=always --line-range=:100 {} 2>/dev/null || head -100 {}')
    if test -n "$file"
        set -l editor nvim
        if test -n "$EDITOR"
            set editor $EDITOR
        end
        $editor "$file"
    end
end
