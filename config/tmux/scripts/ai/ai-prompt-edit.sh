#!/usr/bin/env bash
set -euo pipefail

# ai-prompt-edit.sh - Edit AI prompt using Neovim/vi and paste into tmux pane
#
# Overview:
#   Opens an editor to write a prompt, then pastes it into the target tmux pane.
#   Uses nvim if available, otherwise falls back to vi.
#
# Modes:
#   1. tmux keybinding (normal tmux)
#      → uses display-popup (floating editor)
#   2. iTerm2 coprocess (tmux -CC mode)
#      → fallback to split-window (popup not supported)
#
# Setup:
#   Normal tmux:
#     bind-key -n C-e run-shell "bash ~/.config/tmux/claude-prompt-edit.sh '#{pane_id}'"
#
#   iTerm2 + tmux -CC:
#     iTerm2 → Settings → Profiles → Keys → Key Mappings
#     Shortcut: Ctrl+E
#     Action: Run Coprocess
#     Command: bash ~/.config/tmux/claude-prompt-edit.sh
#
# Notes:
#   - macOS Option (Alt) key combos may not work (dead keys)
#   - PATH may be limited → script searches common binary locations

# log stderr to avoid UI popups

# ===== PATH FIX (tmux popup env) =====
# export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# ================= CONFIG =================
AI_PROMPT_HISTORY="${HOME}/.ai_prompt_history"
AI_PROMPT_TEMPLATES="${HOME}/.ai_prompt_templates"
AI_PROMPT_DB="${HOME}/x/vault/02_areas/AI/Prompts"

FZF_OPTS="--height=80% --layout=reverse --border --preview-window=right:60%"

# ================= BIN =================
bin() {
	command -v "$1" 2>/dev/null || echo "/opt/homebrew/bin/$1"
}

FZF_BIN="$(bin fzf)"
RG_BIN="$(bin rg)"
TMUX_BIN="$(bin tmux)"

# ================= INFRA =================
tmux_run() {
	if [ -n "${TMUX:-}" ]; then
		"$TMUX_BIN" "$@"
	else
		"$TMUX_BIN" -S "/tmp/tmux-$(id -u)/default" "$@"
	fi
}

editor() {
	command -v nvim >/dev/null && nvim "$1" || vi "$1"
}

# ================= CORE =================
select_history() {
	[ -f "$AI_PROMPT_HISTORY" ] || return
	tac "$AI_PROMPT_HISTORY" | "$FZF_BIN" $FZF_OPTS
}

select_template() {
	[ -d "$AI_PROMPT_TEMPLATES" ] || return
	find "$AI_PROMPT_TEMPLATES" -type f |
		"$FZF_BIN" $FZF_OPTS \
			--preview "bat {} 2>/dev/null || cat {}" |
		xargs -I{} cat "{}"
}

select_db() {
	[ -d "$AI_PROMPT_DB" ] || return

	local file
	file=$(
		"$RG_BIN" --files "$AI_PROMPT_DB" |
			sed "s|$AI_PROMPT_DB/||" |
			"$FZF_BIN" $FZF_OPTS \
				--prompt="Prompts > " \
				--preview "bat --style=numbers --color=always \"$AI_PROMPT_DB/{}\" 2>/dev/null || cat \"$AI_PROMPT_DB/{}\"" \
				--bind "ctrl-f:reload($RG_BIN --files-with-matches {q} $AI_PROMPT_DB | sed 's|$AI_PROMPT_DB/||')" \
				--bind "ctrl-d:reload($RG_BIN --files $AI_PROMPT_DB | sed 's|$AI_PROMPT_DB/||')"
	)

	[ -n "${file:-}" ] && cat "$AI_PROMPT_DB/$file"
}

select_prompt() {
	local choice

	choice=$(
		printf "New\nHistory\nTemplates\nSearch DB" |
			"$FZF_BIN" $FZF_OPTS
	)

	case "$choice" in
	"History") select_history ;;
	"Templates") select_template ;;
	"Search DB") select_db ;;
	*) echo "" ;;
	esac
}

# ================= EDITOR =================
run_editor() {
	TMP="$1"
	TARGET="$2"

	editor "$TMP"

	if [ -s "$TMP" ]; then
		CONTENT=$(cat "$TMP")

		mkdir -p "$(dirname "$AI_PROMPT_HISTORY")"
		touch "$AI_PROMPT_HISTORY"

		echo "$CONTENT" >>"$AI_PROMPT_HISTORY"

		"$TMUX_BIN" set-buffer -b ai_prompt -- "$CONTENT"
		"$TMUX_BIN" paste-buffer -b ai_prompt -t "$TARGET"
	fi

	rm -f "$TMP"
}

# ================= UI MODE =================
if [ "${1:-}" = "--ui" ]; then
	TARGET="$2"

	TMP=$(mktemp)

	INITIAL="$(select_prompt || true)"
	echo "$INITIAL" >"$TMP"

	run_editor "$TMP" "$TARGET"
	exit 0
fi

# ================= LAUNCHER =================
tmux_run has-session 2>/dev/null || exit 1

TARGET="${1:-$("$TMUX_BIN" display-message -p '#{pane_id}' 2>/dev/null)}"
[ -z "$TARGET" ] && exit 1

SCRIPT="$0"

if [ -n "${TMUX:-}" ]; then
	"$TMUX_BIN" display-popup -E -w 80% -h 70% -T "AI Prompt" \
		"bash '$SCRIPT' --ui '$TARGET'"
else
	"$TMUX_BIN" split-window -v -l 70% \
		"bash '$SCRIPT' --ui '$TARGET'"
fi

exit 0

main() {
addad
}
