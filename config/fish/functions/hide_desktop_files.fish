# ---
# schema: "mdd-node-v1"
# id: "functions/hide_desktop_files.fish"
# title: "Desktop Icons Visibility Toggle"
# layer: "Functions"
# responsibility: "Toggles the visibility of files/icons on the macOS Desktop and restarts Finder to apply"
# dependencies: ["defaults", "killall"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["macos", "finder", "utility"]
# ---

function hide_desktop_files --description "Toggle visibility of files on the macOS Desktop"
    # Safely read state, default to visible (1/true) if key is missing
    set -l current_state (defaults read com.apple.finder CreateDesktop 2>/dev/null)
    if test $status -ne 0; or test "$current_state" = "1"
        defaults write com.apple.finder CreateDesktop -bool false
        echo "Desktop files are now Hidden."
    else
        defaults write com.apple.finder CreateDesktop -bool true
        echo "Desktop files are now Visible."
    end

    # Restart Finder to apply changes
    killall Finder
end

