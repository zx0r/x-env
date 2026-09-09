# ---
# schema: "mdd-node-v1"
# id: "functions/pwd.fish"
# title: "Pwd"
# layer: "Functions"
# responsibility: "Print working directory with syntax coloring"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-06-25"
# last_commit: "f4adbd9652c78a01f562b7194602f3fa10eeea80"
# tags: []
# ---

function pwd --description "Print working directory with syntax coloring"
    # Execute the built-in pwd with all arguments passed
    set -l path (builtin pwd $argv)
    if test $status -eq 0
        set_color 00ffff # Neon Cyan
        echo $path
        set_color normal
    else
        return $status
    end
end
