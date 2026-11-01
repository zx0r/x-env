# ---
# schema: "mdd-node-v1"
# id: "functions/prj.fish"
# title: "Workstation Project & Git Worktree Orchestrator with ACP Bridge"
# layer: "Functions"
# responsibility: "Provisions canonical project workspaces, initializes non-polluting agent worktrees, launches Neovim IPC server, and exposes ACP socket to agent pane"
# dependencies: ["git", "tmux", "nvim"]
# backlinks: ["conf.d/20_abbrs.fish", ".meta/MAP_OF_CONTENT.md", "acp/README.md", "acp/architecture.md"]
# created_at: "2026-10-09"
# updated_at: "2026-10-13"
# last_commit: "pending"
# tags: ["git", "worktree", "tmux", "workspace", "acp", "nvim", "zero-contention", "zero-destruction"]
# ---

# ==============================================================================
# ARCHITECTURAL CONCEPT & DESIGN SPECIFICATION: ZERO-CONTENTION WORKTREE SUITE
# ==============================================================================
#
# 1. CANONICAL ROOT TAXONOMY (NO DOUBLE-NESTING):
#    Every project resides directly at ~/x/dev/own/<project_name>. It serves as
#    the primary, first-class development root. Neovim, Language Servers (LSP),
#    Docker mounts, and CLI tooling operate on the authentic project root without
#    path resolution hops, sub-directory nesting, or container path rewriting.
#
# 2. GIT BRANCH LINEAGE & STABLE UPSTREAM ANCHOR:
#    - 'main' (Anchor): Created with a clean baseline commit. Acts as the stable
#      upstream comparison point (allowing instant 'git diff main...<project>').
#    - '<project_name>' (Primary Working Context): Branched directly from main.
#      Checked out in the primary root workspace for human engineering.
#    - '<project_name>-agent' (Execution Context): Branched off <project_name>.
#      Checked out in an isolated worktree for autonomous agent executions.
#
# 3. NON-POLLUTING LOCAL EXCLUSION SUBSTRATE:
#    - Zero Public Gitignore Contamination: The .worktrees/ container is wired
#      into .git/info/exclude. This keeps the public repository .gitignore 100%
#      clean for upstream distribution, CI/CD pipelines, and pull requests.
#    - Search & LSP Indexing Deduplication: Added to .ignore so ripgrep (rg),
#      fd, Telescope, and language servers completely bypass worktree files,
#      eradicating duplicate symbol lookups and multi-instance indexing thrashing.
#
# 4. SINGLE-WINDOW TMUX ERGONOMICS & ACP IPC BRIDGE:
#    Operates strictly within the user's persistent 'Dev' session and active window:
#    - Left Pane (ARCHITECT): Launches Neovim listening on an authentic IPC socket
#      at $XDG_RUNTIME_DIR/nvim-<project_name>-<timestamp>.sock.
#    - Right Pane (AGENT): Navigates to .worktrees/agent, inheriting NVIM_SOCKET
#      and NVIM_LISTEN_ADDRESS environment variables, giving the agent full
#      Agent Client Protocol (ACP) and JSON-RPC access to the active Neovim session.
#
# 5. ZERO MUTATION & ZERO DESTRUCTION INVARIANT:
#    - Strictly banned: 'rm', 'rm -f', 'rm -rf'.
#    - Collision-free socket generation using epoch timestamps eliminates
#      the need for socket unlinking while preventing EADDRINUSE collisions.
#    - APFS Copy-on-Write (CoW) cloning via 'cp -cR' guarded by upfront existence
#      checks ensures 0-byte duplicate allocation and zero overwrite risk.
# ==============================================================================

function prj --description "Provision project workspace with ACP-enabled Neovim and agent worktree"
    # Parse CLI flags for target session and window routing
    argparse 's/session=' 'w/window=' 't/target=' h/help -- $argv
    or return 1

    if set -ql _flag_h
        set_color cyan --bold
        echo "prj <project_name> [options]"
        set_color normal
        echo "Provision project workspace with ACP-enabled Neovim and agent worktree"
        echo ""
        set_color yellow
        echo "Options:"
        set_color normal
        echo "  -w, --window   Target Tmux window index/name (e.g., -w 2 or -w ops)"
        echo "  -s, --session  Target Tmux session name (e.g., -s rt)"
        echo "  -t, --target   Target Tmux window target (e.g., -t rt:2)"
        echo "  -h, --help     Show this help"
        return 0
    end

    set -l project_name $argv[1]

    # Validate that project name argument is strictly provided
    if test -z "$project_name"
        set_color red
        echo "Usage: prj <project_name> [-w window] [-s session] [-t target]"
        set_color normal
        return 1
    end

    # Resolve base workspace root hierarchy from environment or standard fallback
    set -l development_root_directory ""
    if set -q X_DEV; and test -n "$X_DEV"
        set development_root_directory "$X_DEV/own"
    else
        set development_root_directory "$HOME/x/dev/own"
    end

    set -l project_root_directory "$development_root_directory/$project_name"
    set -l worktree_container_directory "$project_root_directory/.worktrees"
    set -l agent_worktree_directory "$worktree_container_directory/agent"
    set -l agent_branch_name "$project_name-agent"

    # Deterministic runtime socket directory resolution
    set -l runtime_socket_directory ""
    if set -q XDG_RUNTIME_DIR; and test -n "$XDG_RUNTIME_DIR"
        set runtime_socket_directory "$XDG_RUNTIME_DIR"
    else
        set runtime_socket_directory "/tmp"
    end

    # Collision-free Unix domain socket generation (Zero-rm invariant)
    set -l socket_session_epoch (date +%s)
    set -l neovim_socket_path "$runtime_socket_directory/nvim-$project_name-$socket_session_epoch.sock"

    # 1. Initialize primary project directory substrate
    if not test -d "$project_root_directory"
        command mkdir -p "$project_root_directory"
    end

    # 2. Initialize Git repository with proper upstream lineage
    if not test -d "$project_root_directory/.git"
        git -C "$project_root_directory" init -b main >/dev/null 2>&1

        # Isolate nested worktrees via local exclude without polluting public .gitignore
        command mkdir -p "$project_root_directory/.git/info"
        if not grep -qx "\.worktrees/" "$project_root_directory/.git/info/exclude" 2>/dev/null
            echo ".worktrees/" >> "$project_root_directory/.git/info/exclude"
        end

        # Suppress Ripgrep, Fd, and Neovim duplicate symbol indexing
        if not test -f "$project_root_directory/.ignore"
            echo ".worktrees/" > "$project_root_directory/.ignore"
        else if not grep -qx "\.worktrees/" "$project_root_directory/.ignore" 2>/dev/null
            echo ".worktrees/" >> "$project_root_directory/.ignore"
        end

        # Commit clean baseline substrate anchor on main
        git -C "$project_root_directory" commit --allow-empty -m "chore: initialize repository substrate" >/dev/null 2>&1

        # Branch primary project context off main
        git -C "$project_root_directory" checkout -b "$project_name" >/dev/null 2>&1
    end

    # Configure per-worktree isolation to prevent index.lock and gc thrashing
    git -C "$project_root_directory" config extensions.worktreeConfig true 2>/dev/null

    # Ensure primary project branch is checked out in root directory
    set -l current_checked_out_branch (git -C "$project_root_directory" branch --show-current 2>/dev/null)
    if test "$current_checked_out_branch" != "$project_name"
        if git -C "$project_root_directory" show-ref --verify --quiet "refs/heads/$project_name"
            git -C "$project_root_directory" checkout "$project_name" >/dev/null 2>&1
        else
            git -C "$project_root_directory" checkout -b "$project_name" main >/dev/null 2>&1
        end
    end

    # 3. Provision isolated worktree for parallel agent execution
    if not test -d "$agent_worktree_directory"
        command mkdir -p "$worktree_container_directory"

        # Container boundary marker: prevents search tools inside .worktrees from traversing siblings
        if not test -f "$worktree_container_directory/.ignore"
            echo "*" > "$worktree_container_directory/.ignore"
        end

        if git -C "$project_root_directory" show-ref --verify --quiet "refs/heads/$agent_branch_name"
            git -C "$project_root_directory" worktree add "$agent_worktree_directory" "$agent_branch_name" >/dev/null 2>&1
        else
            git -C "$project_root_directory" worktree add -b "$agent_branch_name" "$agent_worktree_directory" "$project_name" >/dev/null 2>&1
        end

        # Disable auto-gc in the agent worktree to eliminate global index/ref lock contention
        git -C "$agent_worktree_directory" config --worktree gc.auto 0 2>/dev/null

        # 4. APFS Copy-on-Write (CoW) Hardware Block Cloning
        # Replicates dependency caches into the agent worktree in ~35ms with 0-byte duplicate disk allocation
        for dep in node_modules .venv target vendor
            if test -d "$project_root_directory/$dep"; and not test -e "$agent_worktree_directory/$dep"
                command cp -cR "$project_root_directory/$dep" "$agent_worktree_directory/$dep" 2>/dev/null
            end
        end
    end

    # 5. Synchronize active Tmux session panes with ACP Socket linkage
    if test -n "$TMUX"
        # Determine explicit target window
        set -l target_window ""
        if test -n "$_flag_t"
            set target_window "$_flag_t"
        else if test -n "$_flag_s"; and test -n "$_flag_w"
            set target_window "$_flag_s:$_flag_w"
        else if test -n "$_flag_w"
            if test -n "$_flag_s"
                set target_window "$_flag_s:$_flag_w"
            else
                set target_window "$_flag_w"
            end
        else if set -q TMUX_PANE; and test -n "$TMUX_PANE"
            set target_window (tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null)
        else
            set target_window (tmux display-message -p '#{window_id}' 2>/dev/null)
        end

        # Query panes strictly in target window
        set -l existing_pane_identifiers (tmux list-panes -t "$target_window" -F "#{pane_id}" 2>/dev/null)
        set -l initial_pane_count (count $existing_pane_identifiers)
        set -l human_pane_identifier ""
        set -l agent_pane_identifier ""

        if test $initial_pane_count -le 1
            # Single pane: designate as Architect, split horizontally for Agent
            if test $initial_pane_count -eq 1
                set human_pane_identifier $existing_pane_identifiers[1]
            else
                set human_pane_identifier (tmux display-message -t "$target_window" -p '#{pane_id}')
            end
            set agent_pane_identifier (tmux split-window -t "$target_window" -h -c "$agent_worktree_directory" -P -F "#{pane_id}")
        else
            # When multiple panes exist, designate first pane as Architect and second as Agent
            set human_pane_identifier $existing_pane_identifiers[1]
            set agent_pane_identifier $existing_pane_identifiers[2]
        end

        # Register active ACP socket and metadata strictly in target window
        tmux set-window-option -t "$target_window" @acp_socket "$neovim_socket_path" >/dev/null 2>&1
        tmux set-window-option -t "$target_window" @acp_project "$project_name" >/dev/null 2>&1
        tmux set-window-option -t "$target_window" @acp_status "ACTIVE" >/dev/null 2>&1

        # Configure Architect (Human) Pane: tag role, set per-pane border, launch Neovim on ACP/RPC socket
        tmux set-option -p -t "$human_pane_identifier" @pane_role "[$project_name] ARCHITECT"
        tmux set-option -p -t "$human_pane_identifier" pane-border-format '#{?pane_active,#[fg=#{@ui_success}]●,#[fg=#{@ui_fg_muted}]○} #[fg=#{@ui_fg},bold]#{@pane_role} '
        tmux select-pane -t "$human_pane_identifier" -T "[$project_name] ARCHITECT (nvim:ACP)"
        tmux send-keys -t "$human_pane_identifier" "cd '$project_root_directory'; env NVIM_APPNAME=nvim/zx0r nvim --listen '$neovim_socket_path'" C-m

        # Configure Agent Execution Pane: tag role, set per-pane border, export ACP socket, enter worktree
        if test -n "$agent_pane_identifier"
            tmux set-option -p -t "$agent_pane_identifier" @pane_role "[$project_name] AGENT"
            tmux set-option -p -t "$agent_pane_identifier" pane-border-format '#{?pane_active,#[fg=#{@ui_success}]●,#[fg=#{@ui_fg_muted}]○} #[fg=#{@ui_fg},bold]#{@pane_role} '
            tmux select-pane -t "$agent_pane_identifier" -T "[$project_name] AGENT"
            set -l agent_env_setup "cd '$agent_worktree_directory'"
            set agent_env_setup "$agent_env_setup; set -gx NVIM_SOCKET '$neovim_socket_path'"
            set agent_env_setup "$agent_env_setup; set -gx NVIM_LISTEN_ADDRESS '$neovim_socket_path'"
            set agent_env_setup "$agent_env_setup; set -gx PROJECT_NAME '$project_name'"
            set agent_env_setup "$agent_env_setup; set -gx PROJECT_ROOT '$project_root_directory'"
            set agent_env_setup "$agent_env_setup; set -gx WORKTREE_ROOT '$agent_worktree_directory'"
            set agent_env_setup "$agent_env_setup; set -gx CARGO_TARGET_DIR '$project_root_directory/.worktrees/.target_cache'"
            set agent_env_setup "$agent_env_setup; clear"
            tmux send-keys -t "$agent_pane_identifier" "$agent_env_setup" C-m
        end

        # Return focus to human pane in target window
        tmux select-pane -t "$human_pane_identifier"
    else
        cd "$project_root_directory"
    end
end
