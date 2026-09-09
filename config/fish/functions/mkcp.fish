# ---
# schema: "mdd-node-v1"
# id: "functions/mkcp.fish"
# title: "Directory Creation and Copy"
# layer: "Functions"
# responsibility: "Creates destination parent directory if missing and copies files"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["filesystem", "copy"]
# ---

function mkcp --description "Create destination parent directory and copy files"
    if test (count $argv) -lt 2
        echo "Usage: mkcp <src...> <dest>" >&2
        return 1
    end
    set -l dest $argv[-1]
    set -l parent (dirname -- "$dest")
    if not test -d "$parent"
        mkdir -p -- "$parent"
    end
    cp -r $argv
end
