# ---
# schema: "mdd-node-v1"
# id: "completions/mamba.fish"
# title: "Mamba Shell Completions Wrapper"
# layer: "Completions"
# responsibility: "Sources micromamba completions when mamba completion is triggered"
# dependencies: ["completions/micromamba.fish"]
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["mamba", "completions", "performance"]
# ---

if not functions -q __fish_mamba_has_command
    set -l completion_dir (status dirname)
    if test -f "$completion_dir/micromamba.fish"
        source "$completion_dir/micromamba.fish"
    end
end
