# ---
# schema: "mdd-node-v1"
# id: "functions/__secrets_sops_upsert.fish"
# title: "SOPS Master Upsert Helper"
# layer: "Functions"
# responsibility: "Safely updates or inserts a key-value secret into the master SOPS YAML store with interactive confirmation"
# dependencies: []
# backlinks: ["functions/add-secret.fish"]
# created_at: "2026-10-04"
# updated_at: "2026-10-11"
# tags: ["security", "secrets", "helper", "sops"]
# ---

function __secrets_sops_upsert -a key_name value sops_file --description "Upsert key-value pair into master SOPS store"
    # Safe lookup using --arg to prevent jq syntax errors on keys with hyphens or dots
    set -l existing (sops -d --output-type json "$sops_file" 2>/dev/null | command jq -e -r --arg k "$key_name" '
        ($k | split(".")) as $p | (getpath($p) // .[$k] // empty)
    ' 2>/dev/null)

    if test $status -eq 0 -a -n "$existing"
        read -P "⚠️  Key '$key_name' already exists in SOPS master. Overwrite? [y/N] " -l confirm
        if not string match -qi 'y*' "$confirm"
            echo "Aborted." >&2
            return 1
        end
    end

    set -l json_val (echo "$value" | command jq -R .)

    # If key contains dot notation (namespace.key), format tree path as ["namespace"]["key"]
    if string match -q "*.*" "$key_name"
        set -l path_tokens (string split "." "$key_name")
        set -l path_expr ""
        for token in $path_tokens
            set path_expr "$path_expr[\"$token\"]"
        end
        sops --set "$path_expr $json_val" "$sops_file"
    else
        sops --set "[\"$key_name\"] $json_val" "$sops_file"
    end
end
