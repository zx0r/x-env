# ---
# schema: "mdd-node-v1"
# id: "functions/rga-fzf.fish"
# title: "Fuzzy Ripgrep-All Search Selector"
# layer: "Functions"
# responsibility: "Performs fuzzy-searching inside documents and rich files (PDF, docx, etc.) using rga and fzf, and opens the match in Neovim"
# dependencies: ["rga", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["search", "fzf", "utility"]
# ---

function rga-fzf --description "Fuzzy search with ripgrep-all and open in editor"
    if not command -sq rga
        echo "Error: 'rga' is required but not installed." >&2
        return 1
    end
    if not command -sq fzf
        echo "Error: 'fzf' is required but not installed." >&2
        return 1
    end

    set -l rg_prefix 'rga --files-with-matches'
    set -l query ""
    if test (count $argv) -gt 0
        set query $argv[-1]
        if test (count $argv) -gt 1
            set rg_prefix "$rg_prefix $argv[1..-2]"
        end
    end

    set -l file (
        FZF_DEFAULT_COMMAND="$rg_prefix '$query'" \
        fzf --sort \
            --preview='test -n "{}" && rga --pretty --context 5 {q} {}' \
            --phony -q "$query" \
            --bind "change:reload:$rg_prefix {q}" \
            --preview-window='50%:wrap'
    )

    if test -n "$file"
        echo "Opening $file..."
        set -l editor nvim
        if test -n "$EDITOR"
            set editor $EDITOR
        end
        $editor "$file"
    end
end

