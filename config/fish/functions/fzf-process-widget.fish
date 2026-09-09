# ---
# schema: "mdd-node-v1"
# id: "functions/fzf-process-widget.fish"
# title: "Fuzzy Process Selector Widget"
# layer: "Functions"
# responsibility: "Fuzzy searches active system processes to either insert their PID into the command line or kill them"
# dependencies: ["ps", "fzf", "kill"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["system", "fzf", "utility"]
# ---

function fzf-process-widget --description "Fuzzy search active system processes and insert PID or kill"
    # Capture current commandline token to use as initial query
    set -l query (commandline -t)

    # Use 'procs' if installed, otherwise fall back to standard 'ps'
    set -l ps_cmd ps -eo user,pid,ppid,start,time,command
    set -l header "[enter] Insert PID | [ctrl-x] Kill Process"

    # Run FZF and capture selected line
    set -l selected ($ps_cmd | fzf \
        --query="$query" \
        --header="$header" \
        --reverse \
        --preview "echo {}" \
        --preview-window "down:2:wrap" \
        --bind "ctrl-x:execute(kill -9 {2})+reload(ps -eo user,pid,ppid,start,time,command)" \
        --ansi)

    if test -n "$selected"
        # Extract PID (second column in ps output) using in-process tokenizer
        set -l tokens (string match -ra '\S+' -- $selected)
        set -l pid $tokens[2]
        # Insert PID into commandline at cursor
        commandline -t ""
        commandline -it "$pid "
    end

    commandline -f repaint
end

