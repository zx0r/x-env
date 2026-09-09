# ---
# schema: "mdd-node-v1"
# id: "functions/hide.fish"
# title: "Finder Hidden Files Hider"
# layer: "Functions"
# responsibility: "Configures macOS Finder preferences to hide hidden/dot files and restarts the Finder process"
# dependencies: ["defaults", "killall"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["macos", "finder", "utility"]
# ---

function hide --description "Hide hidden files in Finder"
    defaults write com.apple.finder AppleShowAllFiles -boolean false
    killall Finder
end

