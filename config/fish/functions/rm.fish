# ---
# schema: "mdd-node-v1"
# id: "functions/rm.fish"
# title: "Safe rm Adapter (Redirects to trash governor)"
# layer: "Functions"
# responsibility: "Drop-in rm replacement routing all invocations through the Principal-grade trash governor"
# dependencies: ["functions/trash.fish"]
# backlinks: ["conf.d/20-abbr.fish"]
# created_at: "2026-10-03"
# updated_at: "2026-10-03"
# tags: ["rm", "trash", "safety", "governor"]
# ---

function rm --description "Drop-in safe rm wrapper delegating to trash governor"
    trash $argv
end
