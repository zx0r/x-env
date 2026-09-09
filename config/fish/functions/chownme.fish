# ---
# schema: "mdd-node-v1"
# id: "functions/chownme.fish"
# title: "Permissions Ownership Shorthand"
# layer: "Functions"
# responsibility: "Recursively changes file/directory ownership to current user"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["permissions", "chown"]
# ---

function chownme --description "Change ownership of files/directories recursively to current user"
    if test (count $argv) -lt 1
        echo "Usage: chownme <paths...>" >&2
        return 1
    end
    sudo chown -R (whoami) -- $argv
end
