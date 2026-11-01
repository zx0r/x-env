# ---
# schema: "mdd-node-v1"
# id: "config.fish"
# title: "Main Configuration Entrypoint"
# layer: "Entrypoint / Orchestrator"
# responsibility: "Minimal zero-overhead orchestrator entrypoint"
# dependencies: ["conf.d/init.fish"]
# backlinks: ["MAP_OF_CONTENT.md"]
# created_at: "2026-06-24"
# updated_at: "2026-10-16"
# last_commit: "pending"
# tags: ["entrypoint", "zero-overhead", "orchestration"]
# ---

# ━━━ 1. Login-Specific Tasks ━━━━━━━━━━━━━━━━━
if status is-login
    # Machine-specific login hooks
end

# ━━━ 2. Interactive-Specific Tasks ━━━━━━━━━━━
if status is-interactive
    # Machine-specific interactive overrides
end
