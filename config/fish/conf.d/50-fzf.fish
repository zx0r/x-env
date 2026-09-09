# ---
# schema: "mdd-node-v1"
# id: "conf.d/50-fzf.fish"
# title: "Fzf Fuzzy Finder Configuration"
# layer: "Tooling (50-59)"
# responsibility: "Configures FZF preview options, colors, search modes, and sources static fish cache"
# dependencies: []
# backlinks: ["config.fish"]
# created_at: "2026-06-26"
# updated_at: "2026-07-12"
# last_commit: "pending"
# tags: ["fzf", "tooling", "fuzzy-finder", "xdg", "cache"]
# ---

# FZF Preview Options & Bindings combined (prevents variable shadowing and overwriting issues)
set -gx FZF_PREVIEW_OPTS "--preview '/Users/x0r/.config/fish/bin/fzf-preview.sh {1}' --preview-window 'right:70%,border-rounded,hidden'
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
    --bind='ctrl-y:execute-silent(xsel --trim -b <<< {+})'

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
    --bind='ctrl-r:unbind(ctrl-r)+change-prompt(1. code> )+disable-search+reload(rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case {q} || true)+change-preview(/Users/x0r/.config/fish/bin/fzf-preview.sh {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-b)'
    --bind='ctrl-f:unbind(change)+unbind(ctrl-f)+change-prompt(2. files> )+enable-search+reload(fd --type f --hidden --exclude .git || find . -type f || true)+change-preview(/Users/x0r/.config/fish/bin/fzf-preview.sh {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-d)+rebind(ctrl-b)'
    --bind='ctrl-d:unbind(change)+unbind(ctrl-d)+change-prompt(3. dir> )+enable-search+reload(fd --type d --hidden --exclude .git || find . -type d -not -path \"*/.*\" || true)+change-preview(/Users/x0r/.config/fish/bin/fzf-preview.sh {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-b)'
    --bind='ctrl-b:unbind(change)+unbind(ctrl-b)+change-prompt(4. bin> )+enable-search+reload(echo \"\$PATH\" | tr \":\" \"\\n\" | xargs -I{} find {} -maxdepth 1 -type f -perm -111 2>/dev/null || true)+change-preview(/Users/x0r/.config/fish/bin/fzf-preview.sh {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)'
"

set -gx FZF_DEFAULT_OPTS "$FZF_GENERAL_OPTS $FZF_COLOR_OPTS $FZF_PREVIEW_OPTS $FZF_SEARCH_MODE"

# Ensure fzf is installed before setting up key bindings
if status is-interactive
    if type -q fzf
        set -l static_cache_directory_path "$XDG_CACHE_HOME/fish/static_init"
        if test -f "$static_cache_directory_path/fzf.fish"
            source "$static_cache_directory_path/fzf.fish"
        end
    end
end
