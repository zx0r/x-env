# ---
# schema: "mdd-node-v1"
# id: "conf.d/50-fzf.fish"
# title: "Fzf Fuzzy Finder Configuration & Third-Party Tool Integrations"
# layer: "Tooling (50-59)"
# responsibility: "Configures FZF preview options, colors, search modes, sources static fish cache, and bootstraps Tree-sitter completions. Merged from 50-utils.fish (archived 2026-10-04)."
# dependencies: []
# backlinks: ["config.fish"]
# created_at: "2026-06-26"
# updated_at: "2026-10-04"
# last_commit: "pending"
# tags: ["fzf", "tooling", "fuzzy-finder", "xdg", "cache", "tree-sitter", "utils"]
# ---

# FZF is only relevant in interactive shells — heavy env vars must not pollute non-interactive
# subshells (cron, `npm install`, `pip install`, etc.) via envp[] propagation.
status is-interactive; or return

# FZF Preview Options & Bindings combined (prevents variable shadowing and overwriting issues)
set -gx FZF_PREVIEW_OPTS "--preview '$XDG_CONFIG_HOME/fish/bin/fzf-preview.sh {1}' --preview-window 'right:70%,border-rounded,hidden'
    --bind='?:toggle-preview'
    --bind='alt-[:toggle-preview'
    --bind='alt-]:change-preview-window(70%|45%,down,border-top|45%,up,border-bottom|)+show-preview'
    --bind='alt-w:toggle-preview-wrap'
    --bind='ctrl-b:preview-page-up'
    --bind='alt-i:preview-page-up'
    --bind='alt-o:preview-page-down'
    --bind='ctrl-alt-b:preview-up'
    --bind='ctrl-alt-f:preview-down'

    # Execute commands inside fzf
    --bind='alt-e:execute($EDITOR {} >/dev/tty </dev/tty)' \
    --bind='ctrl-v:execute(code {+})' \
    --bind='ctrl-s:toggle-sort' \
    --bind='alt-p:preview-up,alt-n:preview-down' \
    --bind='ctrl-k:preview-up,ctrl-j:preview-down' \
    --bind='alt-e:become($EDITOR {+})'
    --bind='ctrl-y:execute-silent(printf "%s" {+} | pbcopy)'

    # History navigation
    --bind='page-up:prev-history,page-down:next-history' \
    --bind='alt-{:prev-history,alt-}:next-history' \
    --bind='alt-shift-up:prev-history,alt-shift-down:next-history' \
"

# General FZF options
set -gx FZF_GENERAL_OPTS "
    --ansi
    --multi
    --cycle
    --height=80%
    --tabstop=4
    --delimiter=:
    --info=inline-right
    --layout=reverse-list
    --border=rounded
    --border-label='❱❱ fzf search code/files/dir/bin ❱❱'
    --border-label-pos=-5
    --padding=1
    --margin=0
    --prompt='2. files> '
    --marker='❱❱'
    --pointer='➤ '
    --separator=''
    --scrollbar=''
"

# Color scheme (Example: CyberPunk Neon Dark)
set -gx FZF_COLOR_OPTS "
    --color=fg:#5b5d5e,fg+:#2aff00,bg:#000000,bg+:#000000
    --color=hl:#5f87af,hl+:#5fd7ff,info:#afaf87,marker:#001cba
    --color=prompt:#d7005f,spinner:#9dff00,pointer:#48ff00,header:#87afaf
    --color=border:#d000ff,separator:#95ff00,label:#aeaeae,query:#d9d9d9
"

# Search mode switching between code, files, directories, and binaries
set -gx FZF_SEARCH_MODE "
    --bind='change:reload(rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case {q} || true)'
    --bind='start:unbind(change)+unbind(ctrl-f)'
    --bind='ctrl-r:unbind(ctrl-r)+change-prompt(1. code> )+disable-search+reload(rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case {q} || true)+change-preview($XDG_CONFIG_HOME/fish/bin/fzf-preview.sh {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-b)'
    --bind='ctrl-f:unbind(change)+unbind(ctrl-f)+change-prompt(2. files> )+enable-search+reload(fd --type f --hidden --exclude .git || find . -type f || true)+change-preview($XDG_CONFIG_HOME/fish/bin/fzf-preview.sh {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-d)+rebind(ctrl-b)'
    --bind='ctrl-d:unbind(change)+unbind(ctrl-d)+change-prompt(3. dir> )+enable-search+reload(fd --type d --hidden --exclude .git || find . -type d -not -path \"*/.*\" || true)+change-preview($XDG_CONFIG_HOME/fish/bin/fzf-preview.sh {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-b)'
    --bind='ctrl-b:unbind(change)+unbind(ctrl-b)+change-prompt(4. bin> )+enable-search+reload(echo \"\$PATH\" | tr \":\" \"\\n\" | xargs -I{} find {} -maxdepth 1 -type f -perm -111 2>/dev/null || true)+change-preview($XDG_CONFIG_HOME/fish/bin/fzf-preview.sh {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)'
"

set -gx FZF_DEFAULT_OPTS "$FZF_GENERAL_OPTS $FZF_COLOR_OPTS $FZF_PREVIEW_OPTS $FZF_SEARCH_MODE"

# Suppress FZF default Ctrl+R binding so Atuin smart history retains Ctrl+R
set -gx FZF_CTRL_R_COMMAND ""

# JIT FZF: Widgets (fzf-file-widget, fzf-cd-widget) are compiled directly into
# $XDG_CACHE_HOME/fish/static_init/frontend.fish by x_runtimes_build for zero-overhead startup.

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tree-sitter Completions (Merged from 50-utils.fish — 2026-10-04)
# Generated asynchronously once if installed, zero blocking on startup.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
if not test -f "$XDG_CONFIG_HOME/fish/completions/tree-sitter.fish"
    if type -q tree-sitter; and test -n "$XDG_CONFIG_HOME"
        command mkdir -p "$XDG_CONFIG_HOME/fish/completions"
        tree-sitter complete --shell fish >"$XDG_CONFIG_HOME/fish/completions/tree-sitter.fish" 2>/dev/null &
    end
end
