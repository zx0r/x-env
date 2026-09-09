# ---
# schema: "mdd-node-v1"
# id: "functions/generate_gpg_key.fish"
# title: "GPG Key Generator Helper"
# layer: "Functions"
# responsibility: "Provides a simplified command to generate a new GPG key with batch passphrase input and custom expiration period"
# dependencies: ["gpg"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["security", "gpg", "utility"]
# ---

function generate_gpg_key --description "Generate a GPG key non-interactively"
    if not command -sq gpg
        echo "Error: 'gpg' (GnuPG) is required but not installed." >&2
        return 1
    end

    if test (count $argv) -lt 4
        echo "Usage: generate_gpg_key <username> <email> <comment> <passphrase> [expiration_period]" >&2
        echo "Expiration examples: '1y' (one year), '2y', '0' (never expires, default)" >&2
        return 1
    end

    set -l username $argv[1]
    set -l email $argv[2]
    set -l comment $argv[3]
    set -l passphrase $argv[4]
    set -l period $argv[5]

    if test -z "$period"
        set period 0
    end

    echo "Generating GPG key for $username <$email> with comment: $comment and expiration: $period..."

    if not gpg --batch --passphrase "$passphrase" --quick-gen-key "$username <$email>" rsa4096 "$comment" "$period"
        echo "Error: GPG key generation failed. Please check GnuPG settings and inputs." >&2
        return 1
    end

    echo "GPG key generation complete."
end

