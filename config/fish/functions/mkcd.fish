# ---
# schema: "mdd-node-v1"
# id: "functions/mkcd.fish"
# title: "Directory Creation and Navigation"
# layer: "Functions"
# responsibility: "Creates a directory path and immediately changes working directory into it"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["navigation", "management"]
# ---

function mkcd --description "Create a directory path and immediately cd into it"
    if test -z "$argv[1]"
        echo "Usage: mkcd <directory>" >&2
        return 1
    end
    mkdir -p -- "$argv[1]"; and builtin cd "$argv[1]"
end
