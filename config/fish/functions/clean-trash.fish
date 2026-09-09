# ---
# schema: "mdd-node-v1"
# id: "functions/clean-trash.fish"
# title: "Trash Purger"
# layer: "Functions"
# responsibility: "Empties the macOS user Trash directory silently"
# dependencies: ["find"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["filesystem", "utility"]
# ---

function clean-trash --description "Clean the user's Trash directory on macOS"
    if not test -d ~/.Trash
        echo "⚠️ Trash directory does not exist or is not a directory." >&2
        return 1
    end

    # Fast cleanup without prompting
    find ~/.Trash -mindepth 1 -delete 2>/dev/null
    if test $status -eq 0
        echo "✅ Trash cleaned"
    else
        echo "⚠️ Some files blocked (try sudo)"
    end
end

