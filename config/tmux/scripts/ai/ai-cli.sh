# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# AI CLI WRAPPER v2 (Smart Provider Router)
# ~/.config/tmux/scripts/ai-cli.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

#!/usr/bin/env bash

INPUT=$(cat)
PROVIDER=${AI_PROVIDER:-auto}

run_claude() {
	if command -v claude >/dev/null 2>&1; then
		echo "$INPUT" | claude
		return 0
	fi
	return 1
}

run_openai() {
	if command -v openai >/dev/null 2>&1; then
		echo "$INPUT" | openai api chat.completions.create
		return 0
	fi
	return 1
}

run_gemini() {
	if command -v gemini >/dev/null 2>&1; then
		echo "$INPUT" | gemini
		return 0
	fi
	return 1
}

run_opencode() {
	if command -v opencode >/dev/null 2>&1; then
		echo "$INPUT" | opencode
		return 0
	fi
	return 1
}

case "$PROVIDER" in
claude)
	run_claude || echo "Claude not installed"
	;;

openai)
	run_openai || echo "OpenAI CLI not installed"
	;;

gemini)
	run_gemini || echo "Gemini CLI not installed"
	;;

opencode)
	run_opencode || echo "OpenCode CLI not installed"
	;;

auto)
	run_claude || run_gemini || run_openai || run_opencode || echo "No AI CLI available"
	;;
esac
