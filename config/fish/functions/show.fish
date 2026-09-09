# ---
# schema: "mdd-node-v1"
# id: "functions/show.fish"
# title: "Finder Hidden Files Shower"
# layer: "Functions"
# responsibility: "Configures macOS Finder preferences to show all hidden/dot files and restarts the Finder process"
# dependencies: ["defaults", "killall"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["macos", "finder", "utility"]
# ---

function show --description "Show all hidden files in Finder"
    defaults write com.apple.finder AppleShowAllFiles -boolean true
    killall Finder
end

