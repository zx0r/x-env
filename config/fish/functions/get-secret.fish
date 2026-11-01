# ---
# schema: "mdd-node-v1"
# id: "functions/get-secret.fish"
# title: "Tier 2/3 Secrets Retrieval Utility"
# layer: "Functions"
# responsibility: "Fetches secret value from volatile RAM-cache (<1ms latency) with transparent fallback to SOPS store"
# dependencies: ["functions/__secrets_cache_path.fish"]
# backlinks: ["functions/gemini.fish", "MAP_OF_CONTENT.md"]
# created_at: "2026-10-04"
# updated_at: "2026-10-11"
# tags: ["security", "secrets", "jit", "ram-cache", "sops"]
# ---

function get-secret -a key_name -d "Fetch secret (RAM-cache -> SOPS fallback)"
    if test -z "$key_name"
        echo "Usage: get-secret <key_name>" >&2
        return 1
    end

    # 1. Search in volatile RAM-cache (Tier 2, fast < 1ms)
    set -l dec_file (__secrets_cache_path)
    if test -r "$dec_file"
        set -l safe_key (string escape --style=regex "$key_name")
        set -l match (string match -r -m 1 "^$safe_key=(.*)" < "$dec_file" 2>/dev/null)
        if set -q match[2]
            # Strip one layer of balanced surrounding quotes if present (dotenv format)
            set -l raw_val "$match[2]"
            echo (string replace -r '^(["\'])(.*)\1$' '$2' "$raw_val")
            return 0
        end
    end

    # 2. Fallback to SOPS store (Tier 3)
    set -l sops_dir "$HOME/.config"
    set -q XDG_CONFIG_HOME; and set sops_dir "$XDG_CONFIG_HOME"
    set -l sops_file "$sops_dir/secrets.enc.yaml"
    if test -f "$sops_file"
        # Safe jq query via --arg to avoid syntax errors with hyphens and special characters
        # Supports both flat keys and dot-notation paths (e.g., TEST_NS.API_KEY)
        set -l val (sops -d --output-type json "$sops_file" 2>/dev/null | command jq -e -r --arg k "$key_name" '
            ($k | split(".")) as $p |
            (getpath($p) // .[$k] // empty) |
            if type == "string" or type == "number" or type == "boolean" then tostring else empty end
        ' 2>/dev/null)
        if test $status -eq 0 -a -n "$val"
            echo "$val"
            return 0
        end
    end

    return 1
end
