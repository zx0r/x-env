#!/usr/bin/env bash

# ==============================================================================
# FZF Dynamic Mode Switcher & Real-Time Action Generator
# Architecture: Evaluates active mode from state file, computes transitions,
#               and emits atomic FZF action sequences for high-speed switching.
# ==============================================================================

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

ACTION="${1:-cycle-engine}"
STATE_FILE="${2:-/tmp/fzf_search_mode}"
PREVIEW_SCRIPT="${3:-/Users/x0r/.config/fish/bin/fzf-preview.sh}"

if [ ! -x "$PREVIEW_SCRIPT" ]; then
    PREVIEW_SCRIPT="$HOME/.config/fish/bin/fzf-preview.sh"
fi

CURRENT_MODE="files"
if [ -f "$STATE_FILE" ]; then
    CURRENT_MODE="$(cat "$STATE_FILE" 2>/dev/null || echo files)"
fi

emit_action() {
    local target_mode="$1"
    case "$target_mode" in
        code)
            printf "execute-silent(echo code > '%s')+change-prompt(1. code> )+disable-search+reload([ -n \"{q}\" ] && rg --column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case -- {q} || true)+change-preview('%s' {1} {2})+change-preview-window(right:70%%,border-rounded,+{2}+3/3,~3)+rebind(change)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        files)
            printf "execute-silent(echo files > '%s')+change-prompt(2. files> )+enable-search+unbind(change)+reload(fd --type f --exclude .git 2>/dev/null || find . -type f)+change-preview('%s' {1})+change-preview-window(right:70%%,border-rounded)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        dirs)
            printf "execute-silent(echo dirs > '%s')+change-prompt(3. dirs> )+enable-search+unbind(change)+reload(fd --type d --exclude .git 2>/dev/null || find . -type d -not -path '*/.*')+change-preview('%s' {1})+change-preview-window(right:70%%,border-rounded)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        hidden)
            printf "execute-silent(echo hidden > '%s')+change-prompt(4. hidden> )+enable-search+unbind(change)+reload(fd --type f --hidden --no-ignore --exclude .git 2>/dev/null || find . -type f -name '.*')+change-preview('%s' {1})+change-preview-window(right:70%%,border-rounded)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        binary|bin)
            printf "execute-silent(echo binary > '%s')+change-prompt(5. binary> )+enable-search+unbind(change)+reload(fd --type f --exclude .git -x file {} + 2>/dev/null | grep -iE 'binary|mach-o' | cut -d: -f1 || find . -type f -exec file {} + 2>/dev/null | grep 'binary' | cut -d: -f1)+change-preview('%s' {1})+change-preview-window(right:70%%,border-rounded)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        docs)
            printf "execute-silent(echo docs > '%s')+change-prompt(6. docs> )+disable-search+reload([ -n \"{q}\" ] && rga --column --line-number --no-heading --color=always --smart-case -- {q} 2>/dev/null || fd --type f -e pdf -e docx -e doc -e xlsx -e pptx -e epub -e ipynb -e md 2>/dev/null || true)+change-preview('%s' {1} {2})+change-preview-window(right:70%%,border-rounded,+{2}+3/3,~3)+rebind(change)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        git)
            printf "execute-silent(echo git > '%s')+change-prompt(7. git> )+enable-search+unbind(change)+reload(git status --porcelain 2>/dev/null | sed 's/^...//' || true)+change-preview('%s' {1})+change-preview-window(right:70%%,border-rounded)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
        *)
            printf "execute-silent(echo files > '%s')+change-prompt(2. files> )+enable-search+unbind(change)+reload(fd --type f --exclude .git 2>/dev/null || find . -type f)+change-preview('%s' {1})+change-preview-window(right:70%%,border-rounded)" "$STATE_FILE" "$PREVIEW_SCRIPT"
            ;;
    esac
}

case "$ACTION" in
    cycle-engine)
        case "$CURRENT_MODE" in
            code)
                NEXT_MODE="files"
                ;;
            files)
                NEXT_MODE="docs"
                ;;
            *)
                NEXT_MODE="code"
                ;;
        esac
        echo "$NEXT_MODE" > "$STATE_FILE"
        emit_action "$NEXT_MODE"
        ;;

    cycle-type)
        case "$CURRENT_MODE" in
            files)
                NEXT_MODE="dirs"
                ;;
            dirs)
                NEXT_MODE="hidden"
                ;;
            hidden)
                NEXT_MODE="binary"
                ;;
            binary|bin)
                NEXT_MODE="git"
                ;;
            git)
                NEXT_MODE="files"
                ;;
            *)
                NEXT_MODE="files"
                ;;
        esac
        echo "$NEXT_MODE" > "$STATE_FILE"
        emit_action "$NEXT_MODE"
        ;;

    action)
        TARGET_MODE="${4:-$CURRENT_MODE}"
        echo "$TARGET_MODE" > "$STATE_FILE"
        emit_action "$TARGET_MODE"
        ;;

    *)
        emit_action "$CURRENT_MODE"
        ;;
esac
