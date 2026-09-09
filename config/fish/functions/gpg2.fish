# ---
# schema: "mdd-node-v1"
# id: "functions/gpg2.fish"
# title: "Lazy GPG_TTY GPG2 Wrapper"
# layer: "Functions"
# responsibility: "Wraps gpg2 binary to dynamically evaluate and export GPG_TTY on execution, bypassing boot-time subprocess forks"
# dependencies: []
# backlinks: ["conf.d/11-ssh-gpg.fish"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["gpg", "gpg2", "wrapper", "performance"]
# ---

function gpg2 --description "Wrapper for gpg2 to lazily set GPG_TTY"
    if not set -q GPG_TTY
        set -gx GPG_TTY (command tty)
    end
    command gpg2 $argv
end
