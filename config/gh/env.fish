# NOTE:-------------------------------------------------------
#   ██╗  ██╗    W O R K S T A T I O N
#   ╚██╗██╔╝
#    ╚███╔╝     SYSTEMS OVER SCRIPTS
#    ██╔██╗     INTENT OVER DRIFT
#   ██╔╝ ██╗    AUTOMATION WITH CONTROL
#   ╚═╝  ╚═╝
# Toolchain: gh 2.102+ | fzf 0.50+ | delta 0.20+ | jq 1.7+ | bat 0.24+
# Target   : ~/.config/gh/env.fish
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. RUNTIME GOVERNORS & ENVIRONMENT FLAGS
set -gx GH_NO_UPDATE_NOTIFIER 1
set -gx GH_NO_EXTENSION_UPDATE_NOTIFIER 1
if set -q EDITOR
    set -gx GH_EDITOR $EDITOR
else
    set -gx GH_EDITOR nvim
end

# 2. INTERACTIVE FZF POWER EXTENSIONS

function gh-pr-fzf -d "Interactive Pull Request Navigator via fzf"
    set -l pr_number (gh pr list --limit 100 \
        --json number,title,author,headRefName,updatedAt \
        --template '{{range .}}{{tablerow (printf "#%v" .number) .title .headRefName .author.login (timeago .updatedAt)}}{{end}}' | \
        fzf --header "Enter: Checkout | Ctrl-O: Open in Browser | Ctrl-D: Diff" \
            --delimiter '\t' \
            --preview 'gh pr view {1} --comments' \
            --preview-window 'right:60%:wrap' \
            --bind 'ctrl-o:execute-silent(gh pr view {1} --web)+abort' \
            --bind 'ctrl-d:preview(gh pr diff {1} | delta)' | \
        awk '{print $1}' | tr -d '#')

    if test -n "$pr_number"
        gh pr checkout "$pr_number"
    end
end

function gh-issue-fzf -d "Interactive Issue Navigator via fzf"
    set -l issue_number (gh issue list --limit 100 \
        --json number,title,author,state,updatedAt \
        --template '{{range .}}{{tablerow (printf "#%v" .number) .title .state .author.login (timeago .updatedAt)}}{{end}}' | \
        fzf --header "Enter: View in Terminal | Ctrl-O: Open in Browser" \
            --delimiter '\t' \
            --preview 'gh issue view {1} --comments' \
            --preview-window 'right:60%:wrap' \
            --bind 'ctrl-o:execute-silent(gh issue view {1} --web)+abort' | \
        awk '{print $1}' | tr -d '#')

    if test -n "$issue_number"
        gh issue view "$issue_number"
    end
end

function gh-run-fzf -d "Interactive CI/CD Workflow Monitor via fzf"
    set -l run_id (gh run list --limit 50 \
        --json databaseId,workflowName,headBranch,status,conclusion,updatedAt \
        --template '{{range .}}{{tablerow (printf "%v" .databaseId) .workflowName .headBranch .status .conclusion (timeago .updatedAt)}}{{end}}' | \
        fzf --header "Enter: View Logs | Ctrl-R: Rerun Failed | Ctrl-W: Watch" \
            --delimiter '\t' \
            --preview 'gh run view {1}' \
            --preview-window 'right:60%:wrap' \
            --bind 'ctrl-r:execute(gh run rerun {1} --failed)+reload(gh run list --limit 50)' \
            --bind 'ctrl-w:execute(gh run watch {1})' | \
        awk '{print $1}')

    if test -n "$run_id"
        gh run view "$run_id" --log-failed
    end
end

function gh-clone-cd -d "Clone repository via SSH and cd into it"
    if test (count $argv) -eq 0
        echo "Usage: gh-clone-cd <owner/repo>"
        return 1
    end
    set -l repo $argv[1]
    set -l dir_name (string split -r -m1 '/' $repo)[-1]
    set -l dir_name (string replace -r '\.git$' '' $dir_name)
    if gh repo clone "$repo"
        cd "$dir_name"
    end
end
