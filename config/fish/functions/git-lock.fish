# ---
# schema: "mdd-node-v1"
# id: "functions/git-lock.fish"
# title: "Git Zero-Trust Configuration Lock"
# layer: "Functions"
# responsibility: "Enforces kernel immutability (uchg) and POSIX read-only on Git infrastructure"
# dependencies: []
# backlinks: ["conf.d/01_env.fish", "README.md"]
# created_at: "2026-10-11"
# updated_at: "2026-10-11"
# tags: ["git", "security", "zero-trust", "immutability"]
# ---

function git-lock --description "Lock Git configuration with Darwin kernel immutability"
    set -l git_dir "$HOME/.config/git"
    set -l targets \
        "$git_dir/config" \
        "$git_dir/attributes" \
        "$git_dir/ignore" \
        "$git_dir/allowed_signers" \
        "$git_dir/profiles/own.inc" \
        "$git_dir/profiles/nda.inc"

    # 1. Ensure symlink in $HOME is pinned to canonical XDG config
    if not test -L "$HOME/.gitconfig"
        command ln -sfh "$git_dir/config" "$HOME/.gitconfig"
    end
    command chflags -h uchg "$HOME/.gitconfig" 2>/dev/null

    # 2. Apply POSIX read-only and Darwin VFS immutable flag
    for target in $targets
        if test -f "$target"
            command chmod 400 "$target"
            command chflags uchg "$target"
        end
    end

    echo "🔒 Git configuration sealed: Darwin kernel uchg + POSIX 0400 applied."
end
