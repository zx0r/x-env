# ---
# schema: "mdd-node-v1"
# id: "functions/nvim.fish"
# title: "Nvim"
# layer: "Functions"
# responsibility: "Native Neovim launcher with guaranteed cursor restoration"
# dependencies: []
# backlinks: ["conf.d/01_env.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-10"
# last_commit: "pending"
# tags: ["editor", "wrapper", "nvim"]
# ---

function nvim --wraps nvim --description "Native Neovim launcher with guaranteed cursor restoration"
    command nvim $argv

    if status is-interactive
        printf '\e[3 q'
    end
end
