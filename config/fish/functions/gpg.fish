# ---
# schema: "mdd-node-v1"
# id: "functions/gpg.fish"
# title: "Lazy GPG_TTY GPG Wrapper"
# layer: "Functions"
# responsibility: "Wraps gpg binary to dynamically evaluate and export GPG_TTY on execution, bypassing boot-time subprocess forks"
# dependencies: []
# backlinks: ["conf.d/11-ssh-gpg.fish"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["gpg", "wrapper", "performance"]
# ---

function gpg --description "Wrapper for gpg to lazily set GPG_TTY"
    if not set -q GPG_TTY
        set -gx GPG_TTY (command tty)
    end
    command gpg $argv
end
