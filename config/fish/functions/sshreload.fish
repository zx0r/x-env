# ---
# schema: "mdd-node-v1"
# id: "functions/sshreload.fish"
# title: "SSH Agent Reloader"
# layer: "Functions"
# responsibility: "Terminates existing ssh-agent, initializes a new ssh-agent, and loads all private keys from ~/.ssh"
# dependencies: ["ssh-agent", "ssh-add", "pkill"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["security", "ssh", "utility"]
# ---

function sshreload --description "Force reload all SSH configurations and keys"
    pkill -9 ssh-agent
    eval (ssh-agent -c)
    
    set -l keys
    for file in $HOME/.ssh/*
        # Skip directories, public keys, config files, known_hosts, and authorized_keys
        if test -f "$file"
            set -l fname (basename -- "$file")
            if not string match -q "*.pub" -- "$fname"
                and not string match -q "config" -- "$fname"
                and not string match -q "known_hosts" -- "$fname"
                and not string match -q "authorized_keys" -- "$fname"
                set -a keys "$file"
            end
        end
    end

    if test (count $keys) -gt 0
        ssh-add $keys
    else
        echo "No SSH private keys found to add."
    end
end

