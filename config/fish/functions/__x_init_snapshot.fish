# ---
# schema: "mdd-node-v1"
# id: "functions/__x_init_snapshot.fish"
# title: "AOT Monolithic Snapshot Hydrator"
# layer: "Functions / Runtimes"
# responsibility: "Sources pre-compiled AOT monolithic runtime snapshot (~/.cache/fish/aot/snapshot.fish) on the first interactive prompt"
# dependencies: ["functions/__x_build_cache.fish"]
# backlinks: ["conf.d/init.fish"]
# created_at: "2026-10-16"
# updated_at: "2026-10-16"
# tags: ["hydration", "snapshot", "aot", "swr", "zero-fork-sla", "principal"]
# ---

function __x_init_snapshot --description "Hydrate AOT compiled runtime snapshot"
    functions -e __x_init_snapshot
    set -l snapshot "$XDG_CACHE_HOME/fish/aot/snapshot.fish"
    if not test -f "$snapshot"
        __x_build_cache
    end
    if test -f "$snapshot"
        source "$snapshot"
    end
end
