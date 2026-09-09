# ---
# schema: "mdd-node-v1"
# id: "functions/tig.fish"
# title: "Tig Git Interface Wrapper"
# layer: "Functions"
# responsibility: "Wraps the tig text-mode Git interface to check for its existence before launching"
# dependencies: ["tig"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["git", "utility"]
# ---

function tig --description "Text-mode interface for Git"
    if not command -sq tig
        echo "Error: 'tig' is required but not installed. Install it via Homebrew: brew install tig" >&2
        return 1
    end
    command tig $argv
end
