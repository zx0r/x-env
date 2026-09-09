# ---
# schema: "mdd-node-v1"
# id: "functions/git.fish"
# title: "Lazy GPG_TTY Git Wrapper"
# layer: "Functions"
# responsibility: "Wraps git binary to dynamically evaluate and export GPG_TTY on execution, bypassing boot-time subprocess forks"
# dependencies: []
# backlinks: ["conf.d/11-ssh-gpg.fish"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["git", "gpg", "wrapper", "performance"]
# ---

function git --description "Wrapper for git to lazily set GPG_TTY"
    if not set -q GPG_TTY
        set -gx GPG_TTY (command tty)
    end
    command git $argv
end
