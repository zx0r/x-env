# ---
# schema: "mdd-node-v1"
# id: "functions/copy.fish"
# title: "Smart Directory Copy Wrapper"
# layer: "Functions"
# responsibility: "Wraps the system cp command to automatically create parent directories and handle directory path slashes"
# dependencies: ["cp", "mkdir"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["filesystem", "utility"]
# ---

function copy --description "Copy files/directories with automatic parent directory creation"
    if test (count $argv) -eq 0
        command cp
        return
    end

    if test (count $argv) -eq 2; and test -d "$argv[1]"
        # Trim trailing slashes from source path
        set -l from (string replace -r '/+$' '' -- "$argv[1]")
        set -l to "$argv[2]"

        # Create destination's parent directory if it does not exist
        set -l parent_dir (dirname -- "$to")
        if not test -d "$parent_dir"
            mkdir -p -- "$parent_dir"
        end
        command cp -i -r -- "$from" "$to"
    else
        command cp -i $argv
    end
end

