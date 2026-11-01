# ---
# schema: "mdd-node-v1"
# id: "functions/__x_init_eza.fish"
# title: "High-Performance eza Navigation Suite (Single-File Architecture)"
# layer: "Functions / Navigation"
# responsibility: "Initializes EZA_ICONS_AUTO and exports high-density eza wrapper functions (ls, l, ll, la, l., lt, t) with zero shell expansion and zero history pollution"
# dependencies: []
# backlinks: ["conf.d/init.fish"]
# created_at: "2026-10-18"
# updated_at: "2026-10-18"
# last_commit: "pending"
# tags: ["eza", "navigation", "views", "zero-expansion", "principal"]
# ---

function __x_init_eza --description "Initialize eza navigation functions and environment"
    # 1. Environment Optimization (Auto icons in TTY, clean in pipes)
    set -gx EZA_ICONS_AUTO 1

    # Guard: fallback gracefully if eza is not installed
    command -q eza; or return 0

    # 2. Standard Grid Listing
    function ls --wraps eza --description "List directory contents with eza"
        command eza --group-directories-first $argv
    end

    # 3. Standard Long View (Fast, clean metadata, git status)
    function l --wraps eza --description "List directory contents in long format with git status"
        command eza -l --header --group-directories-first --git $argv
    end

    # 4. Dense View (Inodes, owner, group, dual timestamps, git status)
    function ll --wraps eza --description "Dense directory listing with inodes, group, dual timestamps, and git status"
        command eza -abghilmu --git --group-directories-first $argv
    end

    # 5. Compact All Files (Grid view including hidden files)
    function la --wraps eza --description "List all files including hidden"
        command eza -a --group-directories-first $argv
    end

    # 6. Dotfiles Only (Zero-fork native filtering)
    function l. --wraps eza --description "List only hidden/dotfiles"
        command eza -a -d .* $argv
    end

    # 7. Tree Navigation Hierarchy (Levels 1-4)
    function lt --wraps eza --description "List directory tree (depth 2)"
        command eza --tree --level=2 --group-directories-first $argv
    end

    function t --wraps eza --description "List full directory tree"
        command eza --tree --group-directories-first $argv
    end

    function t2 --wraps eza --description "List directory tree (depth 2)"
        command eza --tree --level=2 --group-directories-first $argv
    end

    function t3 --wraps eza --description "List directory tree (depth 3)"
        command eza --tree --level=3 --group-directories-first $argv
    end

    function t4 --wraps eza --description "List directory tree (depth 4)"
        command eza --tree --level=4 --group-directories-first $argv
    end
end
