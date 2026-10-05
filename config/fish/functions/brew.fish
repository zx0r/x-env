# ---
# schema: "mdd-node-v1"
# id: "functions/brew.fish"
# title: "Homebrew JIT Wrapper & Brewfile Synchronization"
# layer: "Functions"
# responsibility: "Wraps brew command to lazily inject brew-wrap for Brewfile sync without startup latency"
# dependencies: ["conf.d/02-brew.fish"]
# backlinks: ["MAP_OF_CONTENT.md"]
# created_at: "2026-10-03"
# updated_at: "2026-10-03"
# tags: ["homebrew", "wrapper", "brewfile", "jit"]
# ---

function brew --description "Homebrew wrapper with lazy brew-wrap and Brewfile sync"
    if test -f "$HOMEBREW_PREFIX/etc/brew-wrap.fish"
        source "$HOMEBREW_PREFIX/etc/brew-wrap.fish"

        function _post_brewfile_update
            echo "🦄 Brewfile was updated successfully ✅"
        end
    end

    command brew $argv
end
