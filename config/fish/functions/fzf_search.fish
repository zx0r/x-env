# ---
# schema: "mdd-node-v1"
# id: "functions/fzf_search.fish"
# title: "Fuzzy Search Engine Entrypoint Alias"
# layer: "Functions"
# responsibility: "First-class ergonomic alias forwarding to autonomous multi-mode search engine fzf_preview"
# dependencies: ["functions/fzf_preview.fish"]
# backlinks: ["conf.d/20-abbr.fish", "MAP_OF_CONTENT.md"]
# created_at: "2026-10-09"
# updated_at: "2026-10-09"
# last_commit: "pending"
# tags: ["fzf", "search", "alias", "engine"]
# ---

function fzf_search --description "Ergonomic entrypoint for autonomous fuzzy search engine"
    fzf_preview $argv
end
