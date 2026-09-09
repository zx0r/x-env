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

function gemini --description "Wrap Gemini CLI with terminal colors"
    set -lx TERM xterm-256color
    set -lx COLORTERM truecolor
    command gemini $argv
end

