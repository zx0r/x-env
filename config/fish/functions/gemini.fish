# ---
# schema: "mdd-node-v1"
# id: "functions/gemini.fish"
# title: "Gemini CLI Color Wrapper"
# layer: "Functions"
# responsibility: "Wraps gemini command to ensure xterm-256color and truecolor environment variables are set during execution"
# dependencies: ["gemini"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["terminal", "utility"]
# ---

function gemini --wraps=gemini --description "Gemini CLI with JIT SOPS token and truecolor"
    set -lx GEMINI_API_KEY (get-secret GEMINI_API_KEY)
    or begin; echo "✗ GEMINI_API_KEY not found. Run: add-secret --ram GEMINI_API_KEY" >&2; return 1; end
    set -lx TERM xterm-256color
    set -lx COLORTERM truecolor
    command gemini $argv
end

