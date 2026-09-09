# ---
# schema: "mdd-node-v1"
# id: "functions/mamba.fish"
# title: "Lazy Mamba Wrapper"
# layer: "Functions"
# responsibility: "Delegates calls directly to the lazy micromamba function wrapper"
# dependencies: ["functions/micromamba.fish"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["mamba", "lazy-load", "performance"]
# ---

function mamba --description "Delegates to lazy micromamba function"
    micromamba $argv
end
