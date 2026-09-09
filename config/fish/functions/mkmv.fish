# ---
# schema: "mdd-node-v1"
# id: "functions/mkmv.fish"
# title: "Directory Creation and Move"
# layer: "Functions"
# responsibility: "Creates destination parent directory if missing and moves files"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["filesystem", "move"]
# ---

function mkmv --description "Create destination parent directory and move files"
    if test (count $argv) -lt 2
        echo "Usage: mkmv <src...> <dest>" >&2
        return 1
    end
    set -l dest $argv[-1]
    set -l parent (dirname -- "$dest")
    if not test -d "$parent"
        mkdir -p -- "$parent"
    end
    mv $argv
end
