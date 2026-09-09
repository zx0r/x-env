# ---
# schema: "mdd-node-v1"
# id: "functions/chmodx.fish"
# title: "Permissions Executable Shorthand"
# layer: "Functions"
# responsibility: "Makes specified files executable"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["permissions", "chmod"]
# ---

function chmodx --description "Make specified files executable"
    if test (count $argv) -lt 1
        echo "Usage: chmodx <files...>" >&2
        return 1
    end
    chmod +x -- $argv
end
