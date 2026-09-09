# ---
# schema: "mdd-node-v1"
# id: "functions/up.fish"
# title: "Directory Navigation Upward Helper"
# layer: "Functions"
# responsibility: "Moves shell working directory up N levels"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["navigation", "helper"]
# ---

function up --description "Move up N levels in the directory tree"
    set -l level 1
    if test (count $argv) -gt 0; and string match -qr '^[0-9]+$' -- $argv[1]
        set level $argv[1]
    end
    set -l path ""
    for i in (seq 1 $level)
        set path "$path../"
    end
    builtin cd "$path"
end
