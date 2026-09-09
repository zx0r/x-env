# ---
# schema: "mdd-node-v1"
# id: "functions/sync_screencapture.fish"
# title: "macOS Screenshot Location Synchronizer"
# layer: "Functions"
# responsibility: "Synchronizes the system screenshot storage location to the designated XDG_SCREENSHOTS_DIR and restarts SystemUIServer"
# dependencies: ["defaults", "killall", "realpath"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["macos", "system", "utility", "x-workspace"]
# ---

function sync_screencapture --description "Synchronize macOS screenshot directory to designated Screenshots folder"
    set -l screenshots_dir (set -q XDG_PICTURES_DIR; and echo "$XDG_PICTURES_DIR/Screenshots"; or echo "$HOME/Pictures/Screenshots")

    if not test -d "$screenshots_dir"
        mkdir -p -m 700 "$screenshots_dir"
    end

    set -l current_loc (defaults read com.apple.screencapture location 2>/dev/null)
    set -l target_loc (realpath "$screenshots_dir")

    if test "$current_loc" != "$target_loc"
        echo "Updating macOS screenshot location to: $target_loc"
        defaults write com.apple.screencapture location "$target_loc"
        killall SystemUIServer 2>/dev/null
        echo "SystemUIServer restarted successfully."
    else
        echo "macOS screenshot location is already synchronized to: $target_loc"
    end
end
