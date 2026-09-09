# ---
# schema: "mdd-node-v1"
# id: "functions/bin.fish"
# title: "Symlink Binary Helper"
# layer: "Functions"
# responsibility: "Creates a symlink of a specified file in /usr/local/bin"
# dependencies: []
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["system", "filesystem"]
# ---

function bin --description "Create symlink of a file in /usr/local/bin"
    if test -z "$argv[1]"
        echo "Usage: bin <file>" >&2
        return 1
    end

    set -l target_file $argv[1]
    if not test -e "$target_file"
        echo "Error: File '$target_file' does not exist." >&2
        return 1
    end

    set -l real_path (realpath -- "$target_file")
    if not test -w /usr/local/bin
        echo "Error: /usr/local/bin is not writable. Please check permissions." >&2
        return 1
    end

    ln -sf -- "$real_path" /usr/local/bin/
end

