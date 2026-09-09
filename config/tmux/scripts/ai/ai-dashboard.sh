# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# TMUX AI SYSTEM v2 (Multi-Provider + Smart Routing)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

##### AI DASHBOARD #####
# ~/.config/tmux/scripts/ai-dashboard.sh

#!/usr/bin/env bash
clear

PROVIDERS=("auto" "claude" "openai" "gemini" "opencode")

choose_provider() {
	echo "Select AI provider:"
	for i in "${!PROVIDERS[@]}"; do
		echo "$i) ${PROVIDERS[$i]}"
	done
	echo -n "> "
	read p
	export AI_PROVIDER="${PROVIDERS[$p]}"
}

choose_provider

clear

echo "=== AI DASHBOARD ($AI_PROVIDER) ==="
echo "1) Chat"
echo "2) Explain current project"
echo "3) Git status summary"
echo "4) Logs analysis"
echo "5) Analyze current pane"
echo "6) Quick command help"

echo -n "> "
read choice

case $choice in
1)
	~/.config/tmux/scripts/ai-cli.sh
	;;

2)
	echo "Explain this project:" | cat - <(tree -L 2 2>/dev/null) | ~/.config/tmux/scripts/ai-cli.sh
	;;

3)
	git status | ~/.config/tmux/scripts/ai-cli.sh
	;;

4)
	tail -n 200 ~/.logs/app.log 2>/dev/null | ~/.config/tmux/scripts/ai-cli.sh
	;;

5)
	tmux capture-pane -p | ~/.config/tmux/scripts/ai-cli.sh
	;;

6)
	echo "Explain this command:"
	read cmd
	echo "$cmd" | ~/.config/tmux/scripts/ai-cli.sh
	;;
esac
