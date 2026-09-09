# ---
# schema: "mdd-node-v1"
# id: "functions/compress.fish"
# title: "Smart Compression Wrapper"
# layer: "Functions"
# responsibility: "Compresses files and directories into specified formats (zip, tar, rar, etc.) using optimal CLI flags"
# dependencies: ["tar", "zip", "rar"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["filesystem", "utility"]
# ---

function compress --description "Compress files and directories into various formats"
    if test (count $argv) -lt 2
        echo "Usage: compress <archive_name.ext> <files_to_compress...>" >&2
        return 1
    end

    set -l archive "$argv[1]"
    set -l files $argv[2..-1]

    # Check that all source files/directories exist
    for f in $files
        if not test -e "$f"
            echo "Error: Source path '$f' does not exist." >&2
            return 1
        end
    end

    switch "$archive"
        case "*.tar"
            tar -cvf "$archive" $files
        case "*.tar.bz2" "*.tbz" "*.tbz2"
            tar -cvjf "$archive" $files
        case "*.tar.xz" "*.txz"
            tar -cvJf "$archive" $files
        case "*.tar.gz" "*.tgz"
            tar -cvzf "$archive" $files
        case "*.zip"
            zip -r "$archive" $files
        case "*.rar"
            rar a "$archive" $files
        case "*"
            echo "Error: Unsupported archive format for '$archive'." >&2
            return 1
    end
end
