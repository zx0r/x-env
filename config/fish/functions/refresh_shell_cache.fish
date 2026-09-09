# ---
# schema: "mdd-node-v1"
# id: "functions/refresh_shell_cache.fish"
# title: "Shell Cache Purge & Reload Utility"
# layer: "Functions"
# responsibility: "Purges the static initialization cache and restarts the shell session"
# dependencies: []
# backlinks: ["conf.d/10-runtimes.fish"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["cache", "reload", "utility"]
# ---

function refresh_shell_cache --description "Clear static fish shell cache and reload"
    rm -rf "$XDG_CACHE_HOME/fish/static_init"
    exec fish
end
