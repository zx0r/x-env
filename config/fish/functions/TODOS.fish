# ---
# schema: "mdd-node-v1"
# id: "functions/TODOS.fish"
# title: "Fuzzy Codebase Notes and TODOs Selector"
# layer: "Functions"
# responsibility: "Fuzzy lists and selects TODO/FIXME comments in the current codebase"
# dependencies: ["rg", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["rg", "fzf", "todos"]
# ---

function TODOS --description "Fuzzy list all TODO/FIXME comments in codebase"
    if not command -sq rg; or not command -sq fzf
        echo "Error: rg and fzf are required" >&2
        return 1
    end
    set -l rg_prefix "rg --column --hidden --line-number --no-heading --color=always --smart-case \
    '\\\\bFIXME\\\\b|\\\\bFIX\\\\b|\\\\bDISCOVER\\\\b|\\\\bNOTE\\\\b|\\\\bNOTES\\\\b|\\\\bINFO\\\\b|\\\\bOPTIMIZE\\\\b|\\\\bXXX\\\\b|\\\\bEXPLAIN\\\\b|\\\\bTODO\\\\b|\\\\bHACK\\\\b|\\\\bBUG\\\\b|\\\\bBUGS\\\\b'"

    set -l selected (fzf --bind "change:reload:$rg_prefix {q} || true" \
        --ansi --disabled \
        --delimiter : \
        --bind 'ctrl-e:execute($EDITOR (echo {} | cut -d: -f1) >/dev/tty </dev/tty)' \
        --preview 'bat --style=numbers,header,changes,snip --color=always --highlight-line {2} -- {1} 2>/dev/null || head -100 {1}' \
        --preview-window 'default:right:60%:~1:+{2}+3/2:border-left')

    if test -n "$selected"
        set -l parts (string split ":" -- "$selected")
        if test -n "$parts[1]"
            set -l editor nvim
            if test -n "$EDITOR"
                set editor $EDITOR
            end
            $editor "+$parts[2]" -- "$parts[1]"
        end
    end
end
