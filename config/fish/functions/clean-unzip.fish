# ---
# schema: "mdd-node-v1"
# id: "functions/clean-unzip.fish"
# title: "Clean Unzip Helper"
# layer: "Functions"
# responsibility: "Safely extracts zip files, automatically nesting dirty archives (archives without a single root directory) inside a subfolder"
# dependencies: ["unzip", "sort"]
# backlinks: ["functions/extract.fish"]
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["filesystem", "utility"]
# ---

function clean-unzip --description "Unzip a file, creating a container folder if it contains multiple root files"
    if test -z "$argv[1]"
        echo "Usage: clean-unzip <file.zip>" >&2
        return 1
    end

    set -l zipfile $argv[1]
    if not string match -q "*.zip" -- "$zipfile"
        echo "Error: Argument must be a .zip file" >&2
        return 1
    end

    if not test -f "$zipfile"
        echo "Error: File '$zipfile' does not exist." >&2
        return 1
    end

    # Determine if the zip is clean (has a single root directory)
    set -l files (unzip -Z1 -- "$zipfile" 2>/dev/null)
    set -l root_dirs (string replace -r '/.*' '' -- $files)
    set -l unique_dirs (string match -r '\S+' -- $root_dirs | sort -u)

    if test (count $unique_dirs) -eq 1
        # Zip is clean, extract directly in place
        unzip -- "$zipfile"
    else
        # Zip is dirty, extract to a directory named after the zip
        set -l folder_name (string replace -r '\.zip$' '' -- (basename -- "$zipfile"))
        mkdir -p -- "$folder_name"
        unzip -- "$zipfile" -d "$folder_name"
    end
end
