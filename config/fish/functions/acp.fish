# ---
# schema: "mdd-node-v1"
# id: "functions/acp.fish"
# title: "Agent Client Protocol (ACP) CLI Helper"
# layer: "Functions"
# responsibility: "High-performance, non-destructive CLI bridge to Neovim ACP MessagePack-RPC server over Unix Domain Socket"
# dependencies: ["nvim", "python3"]
# backlinks: ["functions/prj.fish", "acp/README.md", "acp/architecture.md", "acp/AGENTS.md"]
# created_at: "2026-10-12"
# updated_at: "2026-10-12"
# last_commit: "pending"
# tags: ["acp", "nvim", "ipc", "rpc", "agent", "zero-destruction"]
# ---

function __acp_is_socket_alive --argument-names sock_candidate
    test -n "$sock_candidate"; or return 1
    test -S "$sock_candidate"; or return 1
    command nvim --headless --server "$sock_candidate" --remote-expr 'v:true' >/dev/null 2>&1
end

function acp --description "Agent Client Protocol CLI bridge for Neovim IPC introspection and control"
    set -l subcommand $argv[1]

    # Resolve active Neovim Unix domain socket without disk mutation
    set -l socket_path ""

    # Priority 1: Direct environment override
    if set -q NVIM_SOCKET; and test -n "$NVIM_SOCKET"; and __acp_is_socket_alive "$NVIM_SOCKET"
        set socket_path "$NVIM_SOCKET"
    else if set -q NVIM_LISTEN_ADDRESS; and test -n "$NVIM_LISTEN_ADDRESS"; and __acp_is_socket_alive "$NVIM_LISTEN_ADDRESS"
        set socket_path "$NVIM_LISTEN_ADDRESS"
    end

    # Priority 2: Query active Tmux window variable
    if test -z "$socket_path"; and test -n "$TMUX"
        set -l tmux_sock (tmux show-window-option -v @acp_socket 2>/dev/null)
        if test -n "$tmux_sock"; and __acp_is_socket_alive "$tmux_sock"
            set socket_path "$tmux_sock"
        end
    end

    # Priority 3: Probe runtime directories for active listening socket
    if test -z "$socket_path"
        set -l search_dirs
        if set -q XDG_RUNTIME_DIR; and test -n "$XDG_RUNTIME_DIR"
            set -a search_dirs "$XDG_RUNTIME_DIR"
        end
        set -a search_dirs "/tmp"

        for sdir in $search_dirs
            for sock_candidate in $sdir/nvim-*.sock
                if __acp_is_socket_alive "$sock_candidate"
                    set socket_path "$sock_candidate"
                    break
                end
            end
            if test -n "$socket_path"
                break
            end
        end
    end

    # Handle help or no arguments
    if test -z "$subcommand"; or test "$subcommand" = "help"; or test "$subcommand" = "-h"; or test "$subcommand" = "--help"
        set_color cyan --bold
        echo "Agent Client Protocol (ACP) CLI Suite v2.4-GOLD"
        set_color normal
        echo "Deterministic Unix Domain Socket IPC Bridge to Neovim"
        echo ""
        set_color yellow
        echo "Usage:"
        set_color normal
        echo "  acp ping                         Probe socket connectivity and measure RTT latency"
        echo "  acp context [--json]             Extract active buffer, cursor position, and diagnostics"
        echo "  acp diags                        Display live compiler / LSP diagnostics for active buffer"
        echo "  acp notify <message> [--level L] Send non-intrusive notification to Architect pane"
        echo "  acp read [buffer_or_file]        Read buffer lines in-memory without disk interaction"
        echo "  acp reload                       Dispatch non-destructive checktime buffer refresh"
        echo "  acp status                       Inspect ACP socket, environment, and worktree bounds"
        echo ""
        if test -n "$socket_path"
            set_color green
            echo "● Active Socket: $socket_path"
            set_color normal
        else
            set_color red
            echo "○ No active Neovim ACP socket detected in environment"
            set_color normal
        end
        return 0
    end

    # Ensure valid socket before attempting RPC communication
    if test -z "$socket_path"
        set_color red --bold
        echo "error: No active Neovim ACP server socket detected."
        set_color normal
        echo "Ensure Neovim is running with '--listen <socket>' (or launch workspace via 'prj <name>')."
        return 1
    end

    switch $subcommand
        case ping
            set -l start_ms (command python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null; or echo 0)
            set -l response (command nvim --headless --server "$socket_path" --remote-expr 'luaeval("vim.json.encode(_G.ACP.ping())")' 2>&1)
            set -l end_ms (command python3 -c 'import time; print(int(time.time() * 1000))' 2>/dev/null; or echo 0)

            if test -z "$response"
                set_color red
                echo "✗ Ping failed: Neovim server at $socket_path did not respond"
                set_color normal
                return 1
            end

            set -l rtt_text ""
            if test "$start_ms" -gt 0; and test "$end_ms" -gt 0
                set -l rtt (math "$end_ms - $start_ms")
                set rtt_text " (RTT: "$rtt"ms)"
            end

            set_color green --bold
            echo "● ACP Pong: Connected to Neovim$rtt_text"
            set_color normal
            echo "  Socket:  $socket_path"
            printf '%s\n' "$response" | command python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
pid = data.get("pid")
cwd = data.get("cwd")
up = data.get("uptime_s", 0)
ver = data.get("version", {}).get("build", "unknown")
print(f"  PID:     {pid} | Uptime: {up}s | Build: {ver}")
print(f"  Root:    {cwd}")
'

        case context
            set -l json_mode 0
            if contains -- "--json" $argv
                set json_mode 1
            end

            set -l raw_json (command nvim --headless --server "$socket_path" --remote-expr 'luaeval("vim.json.encode(_G.ACP.get_context())")' 2>&1)
            if test -z "$raw_json"
                set_color red
                echo "error: Failed to query ACP context from Neovim server"
                set_color normal
                return 1
            end

            if test $json_mode -eq 1
                echo "$raw_json"
                return 0
            end

            # Format human-readable high-density context summary
            printf '%s\n' "$raw_json" | command python3 -c '
import json, sys
data = json.loads(sys.stdin.read())
buf = data.get("buffer", {})
cur = data.get("cursor", {})
srv = data.get("server", {})
diags = data.get("diagnostics", [])
errors = [d for d in diags if d.get("severity") == "ERROR"]
warns = [d for d in diags if d.get("severity") == "WARN"]

bname = buf.get("rel_path") or buf.get("name") or "[No Name]"
ftype = buf.get("filetype") or "none"
bufnr = buf.get("bufnr", 0)
lines = buf.get("line_count", 0)
row = cur.get("row", 1)
col = cur.get("col", 1)
tick = buf.get("changedtick", 0)
mod = buf.get("modified", False)

print("\033[1;36m=== NEOVIM ACP CONTEXT ===\033[0m")
print(f"  \033[1mFile:\033[0m         {bname}")
print(f"  \033[1mType:\033[0m         {ftype} | Buf #{bufnr} | Lines: {lines}")
print(f"  \033[1mCursor:\033[0m       Line {row}, Col {col}")
print(f"  \033[1mChangedTick:\033[0m  {tick} (modified: {mod})")
print(f"  \033[1mDiagnostics:\033[0m  \033[31m{len(errors)} errors\033[0m, \033[33m{len(warns)} warnings\033[0m, {len(diags)} total")
'

        case diags
            set -l raw_json (command nvim --headless --server "$socket_path" --remote-expr 'luaeval("vim.json.encode(_G.ACP.get_diagnostics())")' 2>&1)
            if test -z "$raw_json"
                set_color green
                echo "✓ Zero compiler or LSP diagnostics in active Neovim buffer"
                set_color normal
                return 0
            end

            printf '%s\n' "$raw_json" | command python3 -c '
import json, sys
diags = json.loads(sys.stdin.read())
if not diags:
    print("\033[32m✓ Zero compiler or LSP diagnostics in active buffer\033[0m")
    sys.exit(0)

print(f"\033[1;36m=== ACTIVE DIAGNOSTICS ({len(diags)}) ===\033[0m")
for d in diags:
    sev = d.get("severity", "INFO")
    col = "\033[31m" if sev == "ERROR" else ("\033[33m" if sev == "WARN" else "\033[34m")
    lnum = d.get("lnum", 0)
    col_idx = d.get("col", 0)
    src = d.get("source", "lsp")
    msg = d.get("message", "").strip()
    print(f"{col}[{sev:5}]\033[0m Line {lnum}:{col_idx} [{src}]: {msg}")
'

        case notify
            set -l msg $argv[2]
            if test -z "$msg"
                set_color red
                echo "Usage: acp notify <message> [--level info|warn|error]"
                set_color normal
                return 1
            end

            set -l level "info"
            if test (count $argv) -ge 4; and test "$argv[3]" = "--level"
                set level "$argv[4]"
            end

            # Escape message for Lua string injection
            set -l escaped_msg (string replace -a '\\' '\\\\' "$msg" | string replace -a '"' '\\"')
            command nvim --headless --server "$socket_path" --remote-expr "luaeval('_G.ACP.notify(\"$escaped_msg\", \"$level\")')" >/dev/null 2>&1
            set_color green
            echo "✓ Notification dispatched to Architect pane"
            set_color normal

        case read
            set -l target $argv[2]
            set -l lua_arg 'nil'
            if test -n "$target"
                set lua_arg "\"$target\""
            end
            set -l raw_json (command nvim --headless --server "$socket_path" --remote-expr "luaeval('vim.json.encode(_G.ACP.read_buffer($lua_arg))')" 2>&1)
            if test -z "$raw_json"
                set_color red
                echo "error: Failed to read buffer from Neovim"
                set_color normal
                return 1
            end

            printf '%s\n' "$raw_json" | command python3 -c '
import json, sys
res = json.loads(sys.stdin.read())
if res.get("ok"):
    for line in res.get("lines", []):
        print(line)
else:
    print("error:", res.get("error", "unknown error"))
'

        case reload
            set -l res (command nvim --headless --server "$socket_path" --remote-expr 'luaeval("vim.json.encode(_G.ACP.reload_buffer())")' 2>&1)
            set_color green
            echo "✓ Dispatched checktime to active buffer ($res)"
            set_color normal

        case status
            set_color cyan --bold
            echo "=== AGENT CLIENT PROTOCOL (ACP) STATUS ==="
            set_color normal
            echo "  Socket Path:     $socket_path"
            echo "  Socket Liveness: "(__acp_is_socket_alive "$socket_path"; and echo "ACTIVE (listening)"; or echo "UNREACHABLE")
            if test -n "$TMUX"
                echo "  Tmux Session:    "(tmux display-message -p '#S:#I.#P' 2>/dev/null)
                echo "  Tmux @acp_socket:" (tmux show-window-option -v @acp_socket 2>/dev/null; or echo "not set")
                echo "  Tmux @acp_status:" (tmux show-window-option -v @acp_status 2>/dev/null; or echo "not set")
            else
                echo "  Tmux:            Not inside Tmux"
            end
            if test -n "$PROJECT_ROOT"
                echo "  Project Root:    $PROJECT_ROOT"
            end
            if test -n "$WORKTREE_ROOT"
                echo "  Worktree Root:   $WORKTREE_ROOT"
            end

        case '*'
            set_color red
            echo "Unknown ACP command: $subcommand"
            set_color normal
            echo "Run 'acp help' for usage instructions."
            return 1
    end
end
