# ---
# schema: "mdd-node-v1"
# id: "functions/tmx.fish"
# title: "Ultimate Tmux Session Manager"
# layer: "Functions"
# responsibility: "Provides a complete CLI and fuzzy-interactive (fzf) session manager for Tmux, automating workspace provisioning, window layout configurations, session renaming, and process cleanup"
# dependencies: ["tmux", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-07-12"
# last_commit: "pending"
# tags: ["tmux", "fzf", "utility"]
# ---

# ==============================================================================
# TMX - The Ultimate Tmux Session Manager (Fish Shell)
# ==============================================================================

function __tmx_help
    set_color cyan
    echo "████████╗███╗   ███╗██╗  ██╗"
    echo "╚══██╔══╝████╗ ████║╚██╗██╔╝"
    echo "   ██║   ██╔████╔██║ ╚███╔╝ "
    echo "   ██║   ██║╚██╔╝██║ ██╔██╗ "
    echo "   ██║   ██║ ╚═╝ ██║██╔╝ ██╗"
    echo "   ╚═╝   ╚═╝     ╚═╝╚═╝  ╚═╝"
    set_color green
    echo "The Ultimate Tmux Session Manager"
    echo ""
    set_color yellow
    echo "DESCRIPTION:"
    set_color normal
    echo "  A professional Fish shell wrapper for Tmux. Allows you to effortlessly"
    echo "  create, manage, and navigate sessions and windows using fzf."
    echo ""
    set_color yellow
    echo "USAGE:"
    set_color normal
    echo "  tmx                     - 🌟 Open interactive menu (fzf)"
    echo "  tmx new [options]       - ➕ Create a new session"
    echo "  tmx daily               - 🚀 Launch Everyday Workspace (3 windows, 2 panes)"
    echo "  tmx switch | s          - 🔄 Switch to a session (fzf)"
    echo "  tmx kill | k            - ❌ Kill a session (fzf)"
    echo "  tmx rename | rs[name]   - ✏️  Rename current/selected session"
    echo "  tmx rw[name]            - 🪟 Rename current window"
    echo "  tmx kill-server         - 💀 Stop Tmux server completely"
    echo "  tmx ls                  - 📋 List active sessions"
    echo ""
    set_color yellow
    echo "OPTIONS (for 'tmx new'):"
    set_color normal
    echo "  -n, --name     Session name"
    echo "  -w, --windows  Number of windows (optional if -W is provided)"
    echo "  -W, --wnames   Comma-separated window names (e.g., 'web,api,db')"
    echo "  -p, --panes    Number of panes per window"
    echo "  -l, --layout   Layout (tiled, even-horizontal, even-vertical,"
    echo "                         main-horizontal, main-vertical)"
    echo "  -h, --help     Show this help message"
    echo ""
    set_color yellow
    echo "EXAMPLES:"
    set_color normal
    echo "  1. Quick create: tmx -n backend -W \"nvim,server,logs\" -p 2 -l tiled"
    echo "  2. Start daily routine: tmx daily"
end

function __tmx_create
    argparse 'n/name=' 'w/windows=' 'W/wnames=' 'p/panes=' 'l/layout=' h/help -- $argv
    or return 1

    if set -ql _flag_h
        __tmx_help
        return 0
    end

    set -l session_name $_flag_n
    set -l num_windows $_flag_w
    set -l wnames_str $_flag_W
    set -l num_panes $_flag_p
    set -l layout $_flag_l

    if test -z "$session_name"
        set_color blue
        read -P "Session name: " session_name
        set_color normal
        if test -z "$session_name"
            set_color red
            echo "Name cannot be empty!"
            set_color normal
            return 1
        end
    end

    if tmux has-session -t "$session_name" 2>/dev/null
        set_color yellow
        echo "Session '$session_name' already exists. Attaching..."
        set_color normal
        if test -n "$TMUX"
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        end
        return 0
    end

    if test -z "$num_windows" -a -z "$wnames_str"
        set_color blue
        read -P "Number of windows [default 1]: " num_windows
        set_color normal
        if test -z "$num_windows"
            set num_windows 1
        end

        set_color blue
        read -P "Window names (comma-separated, press Enter for default): " wnames_str
        set_color normal
    end

    set -l w_names
    if test -n "$wnames_str"
        for name in (string split "," "$wnames_str")
            set -a w_names (string trim "$name")
        end
    end

    if test -z "$num_windows"
        if test (count $w_names) -gt 0
            set num_windows (count $w_names)
        else
            set num_windows 1
        end
    end

    if test -z "$num_panes"
        set_color blue
        read -P "Panes per window[default 1]: " num_panes
        set_color normal
        test -z "$num_panes"; and set num_panes 1
    end

    if test -z "$layout" -a "$num_panes" -gt 1
        set_color green
        echo "Select layout:"
        echo "  1) tiled (grid)"
        echo "  2) even-horizontal (vertical splits)"
        echo "  3) even-vertical (horizontal splits)"
        echo "  4) main-horizontal"
        echo "  5) main-vertical"
        set_color blue
        read -P "Choice [1]: " layout_choice
        set_color normal
        switch "$layout_choice"
            case 2
                set layout even-horizontal
            case 3
                set layout even-vertical
            case 4
                set layout main-horizontal
            case 5
                set layout main-vertical
            case '*'
                set layout tiled
        end
    else if test -z "$layout"
        set layout tiled
    end

    set_color cyan
    echo "Creating session '$session_name' ($num_windows windows, $num_panes panes per window)..."
    set_color normal

    set -l first_w_name $w_names[1]
    if test -n "$first_w_name"
        tmux new-session -d -s "$session_name" -n "$first_w_name"
    else
        tmux new-session -d -s "$session_name"
    end

    if test "$num_panes" -gt 1
        for p in (seq 2 $num_panes)
            tmux split-window -t "$session_name:"
            tmux select-layout -t "$session_name:" "$layout"
        end
    end

    if test "$num_windows" -gt 1
        for w in (seq 2 $num_windows)
            set -l current_w_name $w_names[$w]
            if test -n "$current_w_name"
                tmux new-window -t "$session_name:" -n "$current_w_name"
            else
                tmux new-window -t "$session_name:"
            end
            if test "$num_panes" -gt 1
                for p in (seq 2 $num_panes)
                    tmux split-window -t "$session_name:"
                    tmux select-layout -t "$session_name:" "$layout"
                end
            end
        end
    end

    tmux select-window -t "$session_name:1" 2>/dev/null; or tmux select-window -t "$session_name:0" 2>/dev/null

    if test -n "$TMUX"
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    end
end

function __tmx_daily_template
    set -l session_name Workspace
    set -l w_names Dev Ops Run
    set -l layout tiled

    if tmux has-session -t "$session_name" 2>/dev/null
        set_color yellow
        echo "Daily Workspace already running. Attaching..."
        set_color normal

        if test -n "$TMUX"
            tmux switch-client -t "$session_name"
        else
            tmux attach-session -t "$session_name"
        end

        return 0
    end

    set_color cyan
    echo "🚀 Booting Daily Workspace..."
    set_color normal

    # DEV -> editor / coding
    tmux new-session -d -s "$session_name" -n $w_names[1]
    tmux split-window -t "$session_name:"
    tmux select-layout -t "$session_name:" even-horizontal

    # OPS -> git / docker / infrastructure
    tmux new-window -t "$session_name:" -n $w_names[2]
    tmux split-window -t "$session_name:"
    tmux select-layout -t "$session_name:" even-horizontal

    # RUN (4 tiled panes) -> runtime / agents / servers / apps
    tmux new-window -t "$session_name:" -n $w_names[3]

    tmux split-window -h -t "$session_name:"
    tmux split-window -v -t "$session_name:".0
    tmux split-window -v -t "$session_name:".1

    tmux select-layout -t "$session_name:" "$layout"

    # Focus DEV
    tmux select-window -t "$session_name:1" 2>/dev/null
    or tmux select-window -t "$session_name:0" 2>/dev/null

    if test -n "$TMUX"
        tmux switch-client -t "$session_name"
    else
        tmux attach-session -t "$session_name"
    end
end

function __tmx_switch
    set -l sessions (tmux list-sessions -F "#{session_name}" 2>/dev/null)
    if test -z "$sessions"
        set_color yellow
        echo "No active Tmux sessions."
        set_color normal
        return 0
    end

    set -l target (printf "%s\n" $sessions | fzf --prompt="🔄 Switch > " --preview="tmux list-windows -t {}" --height=40% --layout=reverse --border)

    if test -n "$target"
        if test -n "$TMUX"
            tmux switch-client -t "$target"
        else
            tmux attach-session -t "$target"
        end
    end
end

function __tmx_kill
    set -l sessions (tmux list-sessions -F "#{session_name}" 2>/dev/null)
    if test -z "$sessions"
        set_color yellow
        echo "No active Tmux sessions."
        set_color normal
        return 0
    end

    set -l target (printf "%s\n" $sessions | fzf --prompt="❌ Kill Session > " --preview="tmux list-windows -t {}" --height=40% --layout=reverse --border --color="prompt:#ff0000")

    if test -n "$target"
        tmux kill-session -t "$target"
        set_color green
        echo "Session '$target' killed."
        set_color normal
    end
end

function __tmx_rename_session
    set -l new_name $argv[1]
    set -l target ""

    if test -z "$TMUX"
        set -l sessions (tmux list-sessions -F "#{session_name}" 2>/dev/null)
        if test -z "$sessions"
            set_color yellow
            echo "No active sessions."
            set_color normal
            return 0
        end
        set target (printf "%s\n" $sessions | fzf --prompt="Rename which session? > " --height=40% --layout=reverse)
        if test -z "$target"
            return 0
        end
    end

    if test -z "$new_name"
        set_color blue
        read -P "New session name: " new_name
        set_color normal
    end

    if test -n "$new_name"
        if test -n "$target"
            tmux rename-session -t "$target" "$new_name"
        else
            tmux rename-session "$new_name"
        end
        set_color green
        echo "Session renamed to '$new_name'."
        set_color normal
    end
end

function __tmx_rename_window
    if test -z "$TMUX"
        set_color yellow
        echo "Error: You must be inside Tmux to rename a window."
        set_color normal
        return 1
    end
    set -l new_name $argv[1]
    if test -z "$new_name"
        set_color blue
        read -P "New window name: " new_name
        set_color normal
    end
    if test -n "$new_name"
        tmux rename-window "$new_name"
        set_color green
        echo "Window renamed to '$new_name'."
        set_color normal
    end
end

function __tmx_interactive_menu
    set -l options "1. 🚀 Launch Daily Workspace" \
        "2. ➕ Create Custom Session" \
        "3. 🔄 Switch session" \
        "4. ❌ Kill session" \
        "5. ✏️  Rename session" \
        "6. 🪟 Rename current window" \
        "7. 💀 Kill Tmux server (KILL ALL)" \
        "8. 🚪 Exit"

    set -l choice (printf "%s\n" $options | fzf --prompt="Tmux Manager > " --height=50% --layout=reverse --border --no-sort | awk '{print $1}')

    switch "$choice"
        case "1."
            __tmx_daily_template
        case "2."
            __tmx_create
        case "3."
            __tmx_switch
        case "4."
            __tmx_kill
        case "5."
            __tmx_rename_session
        case "6."
            __tmx_rename_window
        case "7."
            set_color red
            read -P "⚠️ Kill ALL sessions and stop Tmux? (y/N): " confirm
            set_color normal
            if test "$confirm" = y -o "$confirm" = Y
                tmux kill-server
                set_color green
                echo "Tmux server stopped."
                set_color normal
            end
        case "*"
            return 0
    end
end

# ==============================================================================
# Main Command Router
# ==============================================================================
function tmx --description "The Ultimate Tmux Session Manager"
    if not command -sq tmux
        echo "Error: tmux is required but not installed." >&2
        return 1
    end
    if not command -sq fzf
        echo "Error: fzf is required but not installed." >&2
        return 1
    end

    set -l cmd $argv[1]

    # Auto-detect if flags are passed directly
    if string match -q -- "-*" "$cmd"
        set cmd new
    end

    switch "$cmd"
        case daily work
            __tmx_daily_template
        case new c
            if string match -q -- "-*" $argv[1]
                __tmx_create $argv
            else
                __tmx_create $argv[2..-1]
            end
        case switch s
            __tmx_switch
        case kill k
            __tmx_kill
        case kill-server
            set_color red
            echo "Stopping tmux server..."
            set_color normal
            tmux kill-server
        case rename rs
            __tmx_rename_session $argv[2]
        case rename-window rw
            __tmx_rename_window $argv[2]
        case ls
            tmux list-sessions
        case help -h --help
            __tmx_help
        case ""
            __tmx_interactive_menu
        case "*"
            set_color red
            echo "Unknown command: $cmd"
            set_color normal
            __tmx_help
            return 1
    end
end
