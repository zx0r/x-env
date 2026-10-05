# ---
# schema: "mdd-node-v1"
# id: "functions/zoxide-cd-widget.fish"
# title: "Zoxide Interactive Directory Jumper Widget"
# layer: "Functions"
# responsibility: "Interactive frecency directory selection using zoxide and fzf with instant prompt repaint"
# dependencies: ["zoxide", "fzf"]
# backlinks: ["conf.d/40-keymaps.fish"]
# created_at: "2026-10-04"
# updated_at: "2026-10-04"
# tags: ["navigation", "zoxide", "widget", "keymaps"]
# ---

function zoxide-cd-widget --description "Interactive frecency directory selection using zoxide with instant prompt repaint"
    # Capture current commandline token to pass as initial query if any
    set -l query (commandline -t)

    # Fast-path check for zoxide binary
    if not command -sq zoxide
        return 1
    end

    # Query zoxide interactively (passing query if available)
    set -l result
    if test -n "$query"
        set result (command zoxide query --interactive -- $query 2>/dev/null)
    else
        set result (command zoxide query --interactive 2>/dev/null)
    end

    if test -n "$result" -a -d "$result"
        # Clear current token before cd
        commandline -t ""
        cd -- "$result"
    end

    commandline -f repaint
end
