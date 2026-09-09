# ---
# schema: "mdd-node-v1"
# id: "functions/kitty-reload.fish"
# title: "Kitty Reload"
# layer: "Functions"
# responsibility: "Sends USR1 signal to all running kitty processes to force configuration reload"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-06-25"
# last_commit: "f4adbd9652c78a01f562b7194602f3fa10eeea80"
# tags: ["terminal", "kitty"]
# ---

function kitty-reload --description "Reload Kitty terminal configuration"
    kill -SIGUSR1 (pgrep kitty)
end
