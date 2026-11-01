#!/usr/bin/env bash
# ==============================================================================
# ENTERPRISE GITHUB CLI SHELL INTEGRATION (POSIX / ZSH / BASH)
# Platform : macOS Sequoia / Sonoma (Apple Silicon arm64 Darwin 25+)
# Standards: POSIX.1-2008 / Zsh 5.9+ / Bash 5.2+
# Toolchain: gh 2.102+ | fzf 0.50+ | delta 0.20+ | jq 1.7+ | bat 0.24+
# Target   : /Users/x0r/.config/gh/env.sh
# ==============================================================================

# 1. RUNTIME GOVERNORS & ENVIRONMENT FLAGS
# Suppress synchronous 24-hour update checks across CLI and extension invocations
export GH_NO_UPDATE_NOTIFIER=1
export GH_NO_EXTENSION_UPDATE_NOTIFIER=1

# Editor binding aligned with neovim stack
export GH_EDITOR="${EDITOR:-nvim}"

# 2. SHELL COMPLETIONS LOADER (ZSH / BASH)
if [ -n "${ZSH_VERSION:-}" ]; then
    fpath=(/Users/x0r/.config/gh/completions $fpath)
elif [ -n "${BASH_VERSION:-}" ]; then
    if [ -f "/Users/x0r/.config/gh/completions/gh.bash" ]; then
        source "/Users/x0r/.config/gh/completions/gh.bash"
    fi
fi

# 3. INTERACTIVE FZF POWER EXTENSIONS (PLATFORM UTILITIES)

# Interactive Pull Request Navigator with rich delta preview & checkout
gh-pr-fzf() {
    local pr_number
    pr_number=$(gh pr list --limit 100 \
        --json number,title,author,headRefName,updatedAt \
        --template '{{range .}}{{tablerow (printf "#%v" .number) .title .headRefName .author.login (timeago .updatedAt)}}{{end}}' | \
        fzf --header "Enter: Checkout | Ctrl-O: Open in Browser | Ctrl-D: Diff" \
            --delimiter '\t' \
            --preview 'gh pr view {1} --comments' \
            --preview-window 'right:60%:wrap' \
            --bind 'ctrl-o:execute-silent(gh pr view {1} --web)+abort' \
            --bind 'ctrl-d:preview(gh pr diff {1} | delta)' | \
        awk '{print $1}' | tr -d '#')

    if [ -n "$pr_number" ]; then
        gh pr checkout "$pr_number"
    fi
}

# Interactive Issue Navigator with markdown preview & browser trigger
gh-issue-fzf() {
    local issue_number
    issue_number=$(gh issue list --limit 100 \
        --json number,title,author,state,updatedAt \
        --template '{{range .}}{{tablerow (printf "#%v" .number) .title .state .author.login (timeago .updatedAt)}}{{end}}' | \
        fzf --header "Enter: View in Terminal | Ctrl-O: Open in Browser" \
            --delimiter '\t' \
            --preview 'gh issue view {1} --comments' \
            --preview-window 'right:60%:wrap' \
            --bind 'ctrl-o:execute-silent(gh issue view {1} --web)+abort' | \
        awk '{print $1}' | tr -d '#')

    if [ -n "$issue_number" ]; then
        gh issue view "$issue_number"
    fi
}

# Interactive CI/CD Actions Workflow Monitor with live logs inspection
gh-run-fzf() {
    local run_id
    run_id=$(gh run list --limit 50 \
        --json databaseId,workflowName,headBranch,status,conclusion,updatedAt \
        --template '{{range .}}{{tablerow (printf "%v" .databaseId) .workflowName .headBranch .status .conclusion (timeago .updatedAt)}}{{end}}' | \
        fzf --header "Enter: View Logs | Ctrl-R: Rerun Failed | Ctrl-W: Watch" \
            --delimiter '\t' \
            --preview 'gh run view {1}' \
            --preview-window 'right:60%:wrap' \
            --bind 'ctrl-r:execute(gh run rerun {1} --failed)+reload(gh run list --limit 50)' \
            --bind 'ctrl-w:execute(gh run watch {1})' | \
        awk '{print $1}')

    if [ -n "$run_id" ]; then
        gh run view "$run_id" --log-failed
    fi
}

# Clone repository via SSH protocol and automatically switch into target directory
gh-clone-cd() {
    if [ -z "$1" ]; then
        echo "Usage: gh-clone-cd <owner/repo>"
        return 1
    fi
    local repo="$1"
    local dir_name="${repo##*/}"
    dir_name="${dir_name%.git}"
    gh repo clone "$repo" && cd "$dir_name" || return 1
}
