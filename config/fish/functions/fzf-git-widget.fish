# ---
# schema: "mdd-node-v1"
# id: "functions/fzf-git-widget.fish"
# title: "Fuzzy Git File Selector Widget"
# layer: "Functions"
# responsibility: "Fuzzy searches modified or untracked Git files and inserts their paths into the command line"
# dependencies: ["git", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["git", "fzf", "utility"]
# ---

function fzf-git-widget --description "Fuzzy search modified/untracked Git files and insert into commandline"
    # Ensure we are inside a Git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Not a Git repository"
        commandline -f repaint
        return
    end

    # Capture current commandline token to use as query
    set -l query (commandline -t)

    # Get git status files (short format)
    # Col 1-2: Status, Col 3+: Filepath
    set -l selected (git status --porcelain | fzf \
        --query="$query" \
        --header="[enter] Insert file path | [ctrl-d] View Diff" \
        --reverse \
        --multi \
        --preview "git diff --color=always -- (echo {} | cut -c 4-) | head -100" \
        --preview-window "left:60%:wrap" \
        --bind "ctrl-d:preview(git diff --color=always -- (echo {} | cut -c 4-))" \
        --ansi)

    if test -n "$selected"
        # Parse out files and escape them
        set -l files
        for line in $selected
            set -l file (string sub --start=4 -- $line)
            set -a files (string escape -- $file)
        end
        
        # Insert files into the commandline
        commandline -t ""
        commandline -it (string join " " $files)" "
    end

    commandline -f repaint
end

