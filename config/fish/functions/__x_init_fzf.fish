# ---
# schema: "mdd-node-v1"
# id: "functions/__x_init_fzf.fish"
# title: "Fzf Fuzzy Finder Configuration & Third-Party Tool Integrations"
# layer: "Functions"
# responsibility: "Configures FZF preview options, colors, search modes, sources static fish cache, and bootstraps Tree-sitter completions. Universal search engine pipeline."
# dependencies: ["bin/fzf-preview.sh"]
# backlinks: ["conf.d/init.fish", "functions/fzf_preview.fish"]
# created_at: "2026-06-26"
# updated_at: "2026-10-16"
# last_commit: "pending"
# tags: ["fzf", "search", "tooling", "fuzzy-finder", "xdg", "cache", "tree-sitter", "universal-preview", "search-engine"]
# ---

# ------------------------------------------------------------------------------
# Performance Optimization: Lazy JIT FZF Environment Initialization
# Multi-kilobyte FZF option strings and keybindings are deferred to the first
# fish_prompt event. This eliminates ~500 µs of sequential AST string evaluation
# on the cold interactive boot path.
# ------------------------------------------------------------------------------
function __x_init_fzf --description "Hydrate FZF configuration and environment"

    # Resolve canonical path to preview handler
    set -l fzf_preview_bin "$__fish_config_dir/bin/fzf-preview.sh"
    if not test -x "$fzf_preview_bin"
        set fzf_preview_bin "/Users/x0r/.config/fish/bin/fzf-preview.sh"
    end

    # FZF Preview Options & Bindings combined (prevents variable shadowing and overwriting issues)
    set -gx FZF_PREVIEW_OPTS "--preview '$fzf_preview_bin {1}' --preview-window 'right:70%,border-rounded,hidden'
    --bind='?:toggle-preview'
    --bind='alt-[:toggle-preview'
    --bind='alt-]:change-preview-window(70%|45%,down,border-top|45%,up,border-bottom|hidden)+show-preview'
    --bind='alt-w:toggle-preview-wrap'
    --bind='ctrl-b:preview-page-up'
    --bind='ctrl-f:preview-page-down'
    --bind='alt-i:preview-page-up'
    --bind='alt-o:preview-page-down'
    --bind='ctrl-alt-b:preview-up'
    --bind='ctrl-alt-f:preview-down'
    --bind='ctrl-u:half-page-up,ctrl-d:half-page-down'

    # Execute commands inside fzf
    --bind='alt-e:become(\$EDITOR {+})'
    --bind='ctrl-v:execute(code {+})'
    --bind='ctrl-s:toggle-sort'
    --bind='ctrl-y:execute-silent(printf \"%s\" {+} | pbcopy)'
    --bind='ctrl-o:execute-silent(open {1})'
    --bind='alt-enter:execute-silent(open {1})'

    # History navigation
    --bind='page-up:prev-history,page-down:next-history'
    --bind='alt-{:prev-history,alt-}:next-history'
    --bind='alt-shift-up:prev-history,alt-shift-down:next-history'
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

    # Color scheme (CyberPunk Neon Dark)
    set -gx FZF_COLOR_OPTS "
    --color=fg:#5b5d5e,fg+:#2aff00,bg:#000000,bg+:#000000
    --color=hl:#5f87af,hl+:#5fd7ff,info:#afaf87,marker:#001cba
    --color=prompt:#d7005f,spinner:#9dff00,pointer:#48ff00,header:#87afaf
    --color=border:#d000ff,separator:#95ff00,label:#aeaeae,query:#d9d9d9
"

    # Search mode switching between code (rg), files (fd), directories, rich documents, git, and binaries
    set -gx FZF_SEARCH_MODE "
    --bind='change:reload(rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case {q} || true)'
    --bind='start:unbind(change)+unbind(ctrl-f)+unbind(alt-2)'
    --bind='ctrl-r:unbind(ctrl-r)+change-prompt(1. code> )+disable-search+reload(rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case {q} || true)+change-preview($fzf_preview_bin {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
    --bind='alt-1:unbind(ctrl-r)+change-prompt(1. code> )+disable-search+reload(rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case {q} || true)+change-preview($fzf_preview_bin {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'

    --bind='ctrl-f:unbind(change)+unbind(ctrl-f)+change-prompt(2. files> )+enable-search+reload(fd --type f --hidden --exclude .git 2>/dev/null || find . -type f || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
    --bind='alt-2:unbind(change)+unbind(ctrl-f)+change-prompt(2. files> )+enable-search+reload(fd --type f --hidden --exclude .git 2>/dev/null || find . -type f || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'

    --bind='ctrl-d:unbind(change)+unbind(ctrl-d)+change-prompt(3. dirs> )+enable-search+reload(fd --type d --hidden --exclude .git 2>/dev/null || find . -type d -not -path \"*/.*\" || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
    --bind='alt-3:unbind(change)+unbind(ctrl-d)+change-prompt(3. dirs> )+enable-search+reload(fd --type d --hidden --exclude .git 2>/dev/null || find . -type d -not -path \"*/.*\" || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'

    --bind='ctrl-a:unbind(ctrl-a)+change-prompt(4. docs> )+disable-search+reload(rga --column --line-number --no-heading --color=always --smart-case {q} 2>/dev/null || fd --type f -e pdf -e docx -e doc -e xlsx -e pptx -e epub -e ipynb -e md || true)+change-preview($fzf_preview_bin {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
    --bind='alt-4:unbind(ctrl-a)+change-prompt(4. docs> )+disable-search+reload(rga --column --line-number --no-heading --color=always --smart-case {q} 2>/dev/null || fd --type f -e pdf -e docx -e doc -e xlsx -e pptx -e epub -e ipynb -e md || true)+change-preview($fzf_preview_bin {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-g)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'

    --bind='ctrl-g:unbind(change)+unbind(ctrl-g)+change-prompt(5. git> )+enable-search+reload(git status --porcelain 2>/dev/null | sed \"s/^...//\" || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
    --bind='alt-5:unbind(change)+unbind(ctrl-g)+change-prompt(5. git> )+enable-search+reload(git status --porcelain 2>/dev/null | sed \"s/^...//\" || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-b)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'

    --bind='ctrl-b:unbind(change)+unbind(ctrl-b)+change-prompt(6. bin> )+enable-search+reload(echo \"\$PATH\" | tr \":\" \"\\n\" | while IFS= read -r p; do [ -d \"\$p\" ] && find \"\$p\" -maxdepth 1 -type f -perm -111 2>/dev/null; done || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
    --bind='alt-6:unbind(change)+unbind(ctrl-b)+change-prompt(6. bin> )+enable-search+reload(echo \"\$PATH\" | tr \":\" \"\\n\" | while IFS= read -r p; do [ -d \"\$p\" ] && find \"\$p\" -maxdepth 1 -type f -perm -111 2>/dev/null; done || true)+change-preview($fzf_preview_bin {1})+change-preview-window(right:70%,border-rounded)+rebind(ctrl-r)+rebind(ctrl-f)+rebind(ctrl-d)+rebind(ctrl-a)+rebind(ctrl-g)+rebind(alt-1)+rebind(alt-2)+rebind(alt-3)+rebind(alt-4)+rebind(alt-5)+rebind(alt-6)'
"

    set -gx FZF_DEFAULT_OPTS "$FZF_GENERAL_OPTS $FZF_COLOR_OPTS $FZF_PREVIEW_OPTS $FZF_SEARCH_MODE"
    set -gx FZF_CTRL_R_COMMAND ""
    functions -e __x_init_fzf
end

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tree-sitter Completions (Merged from 50-utils.fish — 2026-10-04)
# Generated asynchronously once if installed, zero blocking on startup.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tree-sitter completions: one-shot provisioning via `fish_update_completions` or manual run.
# Removed from startup path — background fork on every boot is an anti-pattern.
# To generate: tree-sitter complete --shell fish > $XDG_CONFIG_HOME/fish/completions/tree-sitter.fish


