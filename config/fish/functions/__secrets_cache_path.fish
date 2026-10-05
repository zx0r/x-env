# ---
# schema: "mdd-node-v1"
# id: "functions/__secrets_cache_path.fish"
# title: "Volatile Secrets RAM-Cache Path Resolver"
# layer: "Functions"
# responsibility: "Resolves the secure ephemeral RAM-cache file path in UID-isolated $TMPDIR"
# dependencies: []
# backlinks: ["functions/get-secret.fish", "functions/add-secret.fish"]
# created_at: "2026-10-04"
# updated_at: "2026-10-04"
# tags: ["security", "secrets", "helper", "ram-cache"]
# ---

function __secrets_cache_path --description "Resolve path to ephemeral secrets RAM cache"
    if test -n "$TMPDIR"
        echo "$TMPDIR/secrets.env"
    else
        echo "/tmp/secrets_$USER.env"
    end
end
