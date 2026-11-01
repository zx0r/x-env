# ---
# schema: "mdd-node-v1"
# id: "functions/git-unlock.fish"
# title: "Git Configuration Unlock"
# layer: "Functions"
# responsibility: "Releases Darwin kernel immutability (nouchg) and restores POSIX write permissions on Git infrastructure"
# dependencies: []
# backlinks: ["conf.d/01_env.fish", "functions/git-lock.fish", "README.md"]
# created_at: "2026-10-11"
# updated_at: "2026-10-11"
# tags: ["git", "security", "zero-trust", "immutability"]
# ---

function git-unlock --description "Unlock Git configuration for administrative modification"
    set -l git_dir "$HOME/.config/git"
    set -l targets \
        "$git_dir/config" \
        "$git_dir/attributes" \
        "$git_dir/ignore" \
        "$git_dir/allowed_signers" \
        "$git_dir/profiles/own.inc" \
        "$git_dir/profiles/nda.inc"

    # 1. Release immutability on symlink in $HOME
    if test -L "$HOME/.gitconfig"
        command chflags -h nouchg "$HOME/.gitconfig" 2>/dev/null
    end

    # 2. Clear Darwin VFS immutable flag and restore owner read/write permissions
    for target in $targets
        if test -f "$target"
            command chflags nouchg "$target"
            command chmod 600 "$target"
        end
    end

    echo "🔓 Git configuration unlocked: Darwin kernel nouchg + POSIX 0600 restored."
end
