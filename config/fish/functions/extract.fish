# ---
# schema: "mdd-node-v1"
# id: "functions/extract.fish"
# title: "Smart Extraction Wrapper"
# layer: "Functions"
# responsibility: "Extracts compressed archives (zip, tar, gz, 7z, rar, etc.) into a target directory named after the archive, with interactive cleanup"
# dependencies: ["tar", "unzip", "7za", "unrar", "gunzip", "bunzip2"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["filesystem", "utility"]
# ---

function extract --description "Extract bundled & compressed files"
    if test (count $argv) -lt 1
        echo "Usage: extract <archive> [--no-delete]"
        return 1
    end

    set -l archive $argv[1]
    set -l no_delete false
    if test (count $argv) -ge 2; and test "$argv[2]" = "--no-delete"
        set no_delete true
    end

    if not test -f "$archive"
        echo "Error: '$archive' is not a valid file." >&2
        return 1
    end

    # Create target directory based on archive name (remove extension)
    set -l target_dir (basename -- "$archive" | sed 's/\.[^.]*$//')
    mkdir -p -- "$target_dir"

    echo -s "Extracting: " (set_color --bold blue) "$archive" (set_color normal)

    switch "$archive"
        case '*.tar.bz2' '*.tbz' '*.tbz2'
            tar -xvjf "$archive" -C "$target_dir"
        case '*.tar.gz' '*.tgz'
            tar -xvzf "$archive" -C "$target_dir"
        case '*.tar.xz' '*.txz'
            tar -xvJf "$archive" -C "$target_dir"
        case '*.tar.Z'
            tar -xvZf "$archive" -C "$target_dir"
        case '*.bz2'
            bunzip2 -c "$archive" > "$target_dir/"(basename -- "$archive" .bz2)
        case '*.rar'
            unrar x "$archive" "$target_dir/"
        case '*.gz'
            gunzip -c "$archive" > "$target_dir/"(basename -- "$archive" .gz)
        case '*.zip'
            unzip "$archive" -d "$target_dir"
        case '*.Z'
            uncompress -c "$archive" > "$target_dir/"(basename -- "$archive" .Z)
        case '*.7z'
            7za x "$archive" -o"$target_dir"
        case '*'
            echo "Error: Don't know how to extract '$archive'." >&2
            rmdir "$target_dir" 2>/dev/null
            return 1
    end

    if test $status -ne 0
        echo "Error: Extraction failed." >&2
        rmdir "$target_dir" 2>/dev/null
        return 1
    end

    # Handle deletion if --no-delete is not specified
    if not $no_delete
        read -P "Do you want to delete the archive '$archive'? (y/n): " delete_archive
        if test "$delete_archive" = y; or test "$delete_archive" = yes
            rm -f -- "$archive"
            echo "Deleted '$archive'."
        else
            echo "Keeping the archive '$archive'."
        end
    end

    echo "Extraction complete."
end
