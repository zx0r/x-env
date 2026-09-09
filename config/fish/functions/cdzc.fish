# ---
# schema: "mdd-node-v1"
# id: "functions/cdzc.fish"
# title: "Cdzc"
# layer: "Functions"
# responsibility: "Open directories from zoxide in VSCode using zoxide interactive mode"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-06-25"
# last_commit: "f4adbd9652c78a01f562b7194602f3fa10eeea80"
# tags: ["navigation", "zoxide", "vscode"]
# ---

function cdzc --description 'Open directories from zoxide in vscode'
    set selected_dir (zi)

    if test -n "$selected_dir"
        cd "$selected_dir"
        codium -r .
    else
        commandline -f repaint
    end
end
