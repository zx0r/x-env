# ---
# schema: "mdd-node-v1"
# id: "functions/cdf.fish"
# title: "macOS Finder Directory Navigation"
# layer: "Functions"
# responsibility: "Navigates shell working directory to macOS Finder's frontmost path"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["macos", "navigation", "finder"]
# ---

function cdf --description "Change directory to macOS Finder's current target path"
    if not test (uname) = "Darwin"
        echo "Error: cdf is only supported on macOS." >&2
        return 1
    end
    set -l target_path (osascript -e 'tell application "Finder" to get POSIX path of (target of front window as alias)' 2>/dev/null)
    if test -n "$target_path"
        builtin cd "$target_path"
        echo "📂 Navigated to: $target_path"
    else
        echo "Error: Could not retrieve current Finder path." >&2
    end
end
