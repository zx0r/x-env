# ---
# schema: "mdd-node-v1"
# id: "functions/__secrets_sops_upsert.fish"
# title: "SOPS Master Upsert Helper"
# layer: "Functions"
# responsibility: "Safely updates or inserts a key-value secret into the master SOPS YAML store with interactive confirmation"
# dependencies: []
# backlinks: ["functions/add-secret.fish"]
# created_at: "2026-10-04"
# updated_at: "2026-10-04"
# tags: ["security", "secrets", "helper", "sops"]
# ---

function __secrets_sops_upsert -a key_name value sops_file --description "Upsert key-value pair into master SOPS store"
    set -l existing (sops -d --output-type json "$sops_file" 2>/dev/null | command jq -e -r ".$key_name // empty" 2>/dev/null)
    if test $status -eq 0
        read -P "⚠️  Key '$key_name' already exists in SOPS master. Overwrite? [y/N] " -l confirm
        if not string match -qi 'y*' "$confirm"
            echo "Aborted." >&2
            return 1
        end
    end
    set -l json_val (echo "$value" | command jq -R .)
    sops --set "[\"$key_name\"] $json_val" "$sops_file"
end
