# ---
# schema: "mdd-node-v1"
# id: "functions/with-secret.fish"
# title: "Tier 3 Scope-Isolated Secret Execution Wrapper"
# layer: "Functions"
# responsibility: "Executes a command with secrets from a given SOPS namespace injected strictly into process memory scope"
# dependencies: []
# backlinks: ["MAP_OF_CONTENT.md"]
# created_at: "2026-10-04"
# updated_at: "2026-10-04"
# tags: ["security", "secrets", "jit", "sops", "zero-ambient"]
# ---

function with-secret -d "Execute command with SOPS namespace secrets injected"
    set -l namespace $argv[1]
    set -l cmd $argv[2..-1]

    if test -z "$namespace"; or test -z "$cmd[1]"
        echo "Usage: with-secret <namespace> <command...>" >&2
        return 1
    end

    set -l sops_file "$HOME/.config/secrets.enc.yaml"
    if not test -f "$sops_file"
        echo "✗ Error: SOPS file $sops_file not found." >&2
        return 1
    end

    # Parse key-value pairs directly in a single jq pass without pipeline subshell
    set -l entries (sops -d --output-type json "$sops_file" 2>/dev/null | command jq -r ".$namespace | to_entries[] | \"\(.key)=\(.value)\"" 2>/dev/null)
    if test -z "$entries"
        echo "✗ Error: Namespace '$namespace' not found or empty in SOPS." >&2
        return 1
    end

    for entry in $entries
        set -l pair (string split -m 1 = -- $entry)
        set -l key $pair[1]
        set -l val $pair[2]

        # Strict validation of key names to prevent injection
        if not string match -rq '^[A-Za-z_][A-Za-z0-9_]*$' "$key"
            echo "✗ Error: Invalid key name '$key' detected in SOPS namespace '$namespace'. Aborting." >&2
            return 1
        end

        # Direct memory injection into the function scope (exported to child processes)
        set -lx $key "$val"
    end

    # Execute the target command
    $cmd
end
