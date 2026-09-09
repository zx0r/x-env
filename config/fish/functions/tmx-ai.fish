# ---
# schema: "mdd-node-v1"
# id: "functions/tmx-ai.fish"
# title: "Tmux AI Agent Popup Selector"
# layer: "Functions"
# responsibility: "Launches an interactive tmux display-popup containing a menu to select and run various CLI AI assistants (Ollama, TGPT, AIChat, Copilot)"
# dependencies: ["tmux", "fzf"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["tmux", "ai", "fzf", "utility"]
# ---

function tmx-ai --description "Tmux AI Agent Popup Manager"

    # ==========================================================================
    # ВНУТРЕННИЙ ОБРАБОТЧИК (Этот блок запускается уже ВНУТРИ popup-окна)
    # ==========================================================================
    if test "$argv[1]" = --internal
        # Список поддерживаемых AI-инструментов
        set -l options "1. 🦙 Ollama (Локальные нейросети: Llama3, Mistral)" \
            "2. 💬 TGPT (Бесплатный ChatGPT в терминале)" \
            "3. 🧠 AIChat (Мощный клиент для OpenAI/Claude)" \
            "4. 🐙 GitHub Copilot (gh copilot)" \
            "5. ❌ Выход"

        # FZF меню (без рамок, так как рамки уже есть у самого Popup окна Tmux)
        set -l choice (printf "%s\n" $options | fzf --prompt="🤖 Select AI > " \
            --height=100% --layout=reverse --border="none" \
            --color="prompt:#00ff00,pointer:#00aaff")

        # Обработка выбора
        switch "$choice"
            case "1.*"
                if not command -v ollama >/dev/null
                    set_color red
                    echo "Ошибка: Ollama не установлена!"
                    set_color normal
                    echo "Сайт: https://ollama.com/"
                    read -P "Нажмите Enter для выхода..."
                    return
                end

                # Динамически получаем список скачанных локальных моделей
                set -l models (ollama list | awk 'NR>1 {print $1}')
                if test -z "$models"
                    set_color yellow
                    echo "У вас нет установленных моделей. Сначала скачайте, например: ollama run llama3"
                    set_color normal
                    read -P "Нажмите Enter для выхода..."
                    return
                end

                # FZF для выбора конкретной локальной нейросети
                set -l model (printf "%s\n" $models | fzf --prompt="🦙 Select Model > " --height=100% --layout=reverse --border="none")
                if test -n "$model"
                    ollama run "$model"
                end

            case "2.*"
                if not command -v tgpt >/dev/null
                    set_color red
                    echo "Ошибка: TGPT не установлен!"
                    set_color normal
                    echo "Команда для установки: curl -sSL https://raw.githubusercontent.com/aandrew-me/tgpt/main/install | bash -s /usr/local/bin"
                    read -P "Нажмите Enter для выхода..."
                    return
                end
                # Запуск TGPT в интерактивном режиме
                tgpt -i

            case "3.*"
                if not command -v aichat >/dev/null
                    set_color red
                    echo "Ошибка: AIChat не установлен (cargo install aichat)"
                    set_color normal
                    read -P "Нажмите Enter для выхода..."
                    return
                end
                aichat

            case "4.*"
                if not command -v gh >/dev/null
                    set_color red
                    echo "Ошибка: gh cli не установлен!"
                    set_color normal
                    read -P "Нажмите Enter для выхода..."
                    return
                end
                # Запрос подсказки по shell командам у Copilot
                gh copilot suggest -t shell

            case "*"
                return 0
        end
        return 0
    end

    # ==========================================================================
    # ВНЕШНИЙ ОБРАБОТЧИК (Создает само всплывающее окно)
    # ==========================================================================
    if test -z "$TMUX"
        set_color red
        echo "Ошибка: Вы должны находиться внутри Tmux для вызова Popup окна!"
        set_color normal
        return 1
    end

    # Магия Tmux Popup:
    # -E: закрыть окно после завершения
    # -w 80% -h 80%: размер 80% от текущего экрана
    # -d: открыть в текущей директории проекта
    # -T: красивый заголовок сверху в рамке
    tmux display-popup -E -w 80% -h 80% -d "#{pane_current_path}" \
        -T "#[fg=#00aaff,bold] 🤖 AI Workspace #[default]" \
        "fish -c 'tmx-ai --internal'"
end
