# ---
# schema: "mdd-node-v1"
# id: "functions/add-secret.fish"
# title: "Tier 2/3 Secrets Addition Utility"
# layer: "Functions"
# responsibility: "Interactively writes secrets to encrypted SOPS storage and optionally warms the volatile RAM-cache"
# dependencies: ["functions/__secrets_cache_path.fish", "functions/__secrets_sops_upsert.fish"]
# backlinks: ["MAP_OF_CONTENT.md"]
# created_at: "2026-10-04"
# updated_at: "2026-10-04"
# tags: ["security", "secrets", "interactive", "ram-cache", "sops"]
# ---

function add-secret -a backend key_name -d "Add secret [--sops | --ram] <key_name>"
    status is-interactive; or begin; echo "add-secret requires an interactive shell." >&2; return 1; end

    if not contains -- "$backend" "--sops" "--ram"; or test -z "$key_name"
        echo "Usage: add-secret [--sops | --ram] <key_name>" >&2
        return 1
    end

    read -P "🔑 Enter value for $key_name: " -s value
    echo

    set -l sops_file "$HOME/.config/secrets.enc.yaml"
    test -f "$sops_file"; or echo "{}" > "$sops_file"

    __secrets_sops_upsert "$key_name" "$value" "$sops_file"
    if test $status -ne 0
        return 1
    end

    if test "$backend" = "--ram"
        set -l dec_file (__secrets_cache_path)
        set -l tmp_file "$dec_file.tmp.$fish_pid"
        
        command install -m 600 /dev/null "$tmp_file"
        if sops -d --output-type dotenv "$sops_file" > "$tmp_file"
            # Atomic POSIX rename prevents TOCTOU race conditions where another 
            # process reads an empty file during sops decryption.
            command mv "$tmp_file" "$dec_file"
            echo "✔ Saved to SOPS master and updated RAM-cache at $dec_file."
        else
            command rm -f "$tmp_file"
            echo "✗ Error updating RAM-cache." >&2
            return 1
        end
    else
        echo "✔ Saved to SOPS."
    end
end
