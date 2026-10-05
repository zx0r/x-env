# ---
# schema: "mdd-node-v1"
# id: "functions/__fish_theme_migrate.fish"
# title: "Internal Theme Migration Bypass"
# layer: "UX / UI (30-39)"
# responsibility: "Spoofs internal Fish 4.x theme migration to eliminate startup latency overhead"
# dependencies: []
# backlinks: ["themes/default.theme", "conf.d/30-ux.fish"]
# created_at: "2026-09-26"
# updated_at: "2026-10-04"
# tags: ["theme", "zero-fork-sla", "performance", "bypass"]
# ---

function __fish_theme_migrate
    # Zero-Fork SLA: Spoof internal theme migration to save ~0.5ms
    # This prevents Fish 4.x from parsing legacy color variable migration.
end
