# ---
# schema: "mdd-node-v1"
# id: "functions/Rg.fish"
# title: "Interactive Fuzzy Ripgrep Search"
# layer: "Functions"
# responsibility: "Interactive Ripgrep search with FZF"
# dependencies: ["rg", "fzf"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["rg", "fzf", "interactive"]
# ---

function Rg --description "Interactive Ripgrep search with FZF"
    if not command -sq rg; or not command -sq fzf
        echo "Error: rg and fzf are required" >&2
        return 1
    end
    rg --column --line-number --no-heading --color=always --smart-case -- "$argv" 2>/dev/null | fzf --ansi \
        --delimiter : \
        --bind 'ctrl-e:become($EDITOR (echo {} | cut -d: -f1))' \
        --preview 'bat --style=numbers,header,changes,snip --color=always --highlight-line {2} -- {1} 2>/dev/null || head -100 {1}' \
        --preview-window 'default:right:60%:~1:+{2}+3/2:border-left'
end
