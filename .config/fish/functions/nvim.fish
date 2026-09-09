# ---
# schema: "mdd-node-v1"
# id: "functions/nvim.fish"
# title: "Nvim"
# layer: "Functions"
# responsibility: "Wrapper for profile-aware nvimx routing"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["editor", "wrapper", "nvim"]
# ---

function nvim --wraps nvim --description "Wrapper for profile-aware nvimx routing"
    # Route plain `nvim` calls through nvimx (profile-aware)
    # If NVIM_APPNAME is already set, call the real nvim to avoid recursion
    if test -z "$NVIM_APPNAME"; and type -q nvimx
        # If first argument looks like a flag, call real nvim (e.g. --version)
        if test (count $argv) -gt 0; and string match -qr '^-' -- $argv[1]
            command nvim $argv
        else
            nvimx $argv
        end
    else
        command nvim $argv
    end

    # Guaranteed terminal cursor restoration post-TUI exit (blinking underline: \e[3 q)
    if status is-interactive
        echo -en "\e[3 q"
    end
end
