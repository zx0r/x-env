# ---
# schema: "mdd-node-v1"
# id: "functions/zf_search.fish"
# title: "Search Engine Alias"
# layer: "Functions"
# responsibility: "Alias forwarding directly to fzf_search / fzf_preview"
# dependencies: ["functions/fzf_search.fish"]
# backlinks: ["conf.d/20_abbrs.fish", "MAP_OF_CONTENT.md"]
# created_at: "2026-10-09"
# updated_at: "2026-10-10"
# last_commit: "pending"
# tags: ["fzf", "search", "alias"]
# ---

function zf_search --description "Alias forwarding to fzf_search"
    fzf_search $argv
end
