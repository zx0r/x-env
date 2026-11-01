# ---
# schema: "mdd-node-v1"
# id: "functions/fzf_preview.fish"
# title: "Unified Multi-Mode Search Engine"
# layer: "Functions"
# responsibility: "Single self-sufficient interactive search interface with real-time hotkey mode switching and universal preview pipeline"
# dependencies: ["fzf", "bin/fzf-preview.sh", "bin/fzf-mode.sh"]
# backlinks: ["conf.d/50_search.fish", "conf.d/20_abbrs.fish", "functions/fzf_search.fish", "MAP_OF_CONTENT.md"]
# created_at: "2026-07-12"
# updated_at: "2026-10-10"
# last_commit: "pending"
# tags: ["fzf", "search-engine", "unified-interface", "preview", "ripgrep", "fd", "rga", "principal"]
# ---

function fzf_preview --description "Single unified search engine with hotkey mode switching and universal preview pipeline"
    # Ensure fzf is available in the environment
    if not command -sq fzf
        echo "Error: fzf is required but not installed." >&2
        return 1
    end

    # Parse CLI flags using native in-process C++ argparse
    set -l options_spec "h/help" "m/mode=" "q/query=" "p/path=" "H/hidden" "I/no-ignore" "o/open" "c/copy" "e/editor="
    argparse -n fzf_preview $options_spec -- $argv
    or return 1

    # Help documentation banner
    if set -q _flag_help
        echo "Usage: fzf_preview [OPTIONS] [INITIAL_QUERY]"
        echo ""
        echo "Single Unified Search Engine for macOS Apple Silicon"
        echo ""
        echo "Modes (All accessible in real-time via hotkeys within ONE interface):"
        echo "  -m, --mode <MODE>   Initial mode: code, files, dirs, hidden, docs, git, bin (Default: files / code if query passed)"
        echo "  -q, --query <TEXT>  Initial search query"
        echo "  -p, --path <DIR>    Search root directory (Default: current directory)"
        echo "  -H, --hidden        Include hidden files and dotfiles"
        echo "  -I, --no-ignore     Do not respect .gitignore files"
        echo "  -o, --open          Open selection using default macOS handler (open)"
        echo "  -c, --copy          Copy selection directly to macOS clipboard (pbcopy)"
        echo "  -e, --editor <CMD>  Override editor command (Default: \$EDITOR or nvim)"
        echo "  -h, --help          Show this documentation"
        echo ""
        echo "In-Session Cyclic Switchers:"
        echo "  Alt+S               Cycle Search Engine: Code [rg] ⇄ Files [fd] ⇄ Docs [rga]"
        echo "  Alt+T / Ctrl+T      Cycle Target Type: Files → Dirs → Hidden → Binary → Git"
        echo ""
        echo "Direct Mode Jump Hotkeys:"
        echo "  Ctrl+R / Alt+1      [1. Code] Live Ripgrep full-text search with syntax highlight"
        echo "  Ctrl+F / Alt+2      [2. Files] High-performance fuzzy file finder (fd)"
        echo "  Ctrl+D / Alt+3      [3. Dirs] Directory navigator with eza tree preview and auto-cd"
        echo "  Ctrl+H / Alt+4      [4. Hidden] Hidden dotfiles and configurations"
        echo "  Ctrl+B / Alt+5      [5. Binary] Compiled binary & executable files in directory (Mach-O / binary)"
        echo "  Ctrl+A / Alt+6      [6. Docs] Rich documents content search (PDF, DOCX, XLSX, IPYNB, Markdown)"
        echo "  Ctrl+G / Alt+7      [7. Git] Git modified & untracked status with real-time diffs"
        echo ""
        echo "Universal Action Hotkeys:"
        echo "  Enter               Smart Action: Open in editor at line/col, CD into directory, or run command"
        echo "  Ctrl+O / Alt+Enter  Open with native macOS application (open)"
        echo "  Ctrl+V              Open in Visual Studio Code (code)"
        echo "  Ctrl+Y              Copy path/match to macOS clipboard (pbcopy)"
        echo "  ? / Alt+[           Toggle preview window visibility"
        echo "  Alt+]               Cycle preview layout (70% right -> 45% down -> 45% up -> hidden)"
        echo "  Alt+W               Toggle preview line wrapping"
        echo "  Alt+J / Alt+K       Scroll preview down / up"
        echo "  Alt+PageDn/PageUp   Scroll preview page down / page up"
        return 0
    end

    # Resolve target search directory
    set -l target_directory "."
    if set -q _flag_path
        set target_directory $_flag_path
    else if test (count $argv) -gt 1; and test -d "$argv[1]"
        set target_directory $argv[1]
        set -e argv[1]
    end

    # Canonicalize target directory path
    if test "$target_directory" != "."
        builtin cd "$target_directory"
    end

    # Resolve initial query
    set -l initial_query ""
    if set -q _flag_query
        set initial_query $_flag_query
    else if test (count $argv) -gt 0
        set initial_query (string join " " $argv)
    end

    # Resolve initial search mode
    set -l current_mode "files"
    if set -q _flag_mode
        switch $_flag_mode
            case code c rg 1
                set current_mode "code"
            case files f 2
                set current_mode "files"
            case dirs d 3
                set current_mode "dirs"
            case hidden h 4
                set current_mode "hidden"
            case binary bin b 5
                set current_mode "binary"
            case docs rga a 6
                set current_mode "docs"
            case git g 7
                set current_mode "git"
            case "*"
                set current_mode "files"
        end
    else if test -n "$initial_query"
        # If an initial query was supplied without explicit mode, start in live code search
        set current_mode "code"
    end

    # Flags modifiers for hidden / no-ignore
    set -l rg_flags "--column --line-number --no-heading --color=always --colors=match:none --colors=match:fg:yellow --colors=match:style:bold --smart-case"
    set -l fd_flags ""
    if set -q _flag_hidden
        set rg_flags "$rg_flags --hidden"
        set fd_flags "$fd_flags --hidden"
    end
    if set -q _flag_no_ignore
        set rg_flags "$rg_flags --no-ignore"
        set fd_flags "$fd_flags --no-ignore"
    end

    # Path to preview handler script
    set -l preview_script "$__fish_config_dir/bin/fzf-preview.sh"
    if not test -x "$preview_script"
        set preview_script "/Users/x0r/.config/fish/bin/fzf-preview.sh"
    end

    # Create temporary state file to track active mode in real-time across subshell binds
    set -l state_file (mktemp -t fzf_search_mode.XXXXXX 2>/dev/null; or echo "/tmp/fzf_search_mode_"(random))
    echo "$current_mode" > "$state_file"

    # File and content generator commands
    set -l cmd_code "[ -n \"{q}\" ] && rg $rg_flags -- {q} || true"
    set -l cmd_files "fd --type f $fd_flags --exclude .git 2>/dev/null || find . -type f"
    set -l cmd_dirs "fd --type d $fd_flags --exclude .git 2>/dev/null || find . -type d -not -path '*/.*'"
    set -l cmd_hidden "fd --type f --hidden --no-ignore --exclude .git 2>/dev/null || find . -type f -name '.*'"
    set -l cmd_binary "fd --type f $fd_flags --exclude .git -x file {} + 2>/dev/null | grep -iE 'binary|mach-o' | cut -d: -f1 || find . -type f -exec file {} + 2>/dev/null | grep 'binary' | cut -d: -f1"
    set -l cmd_docs "fd --type f -e pdf -e docx -e doc -e xlsx -e pptx -e epub -e ipynb -e md $fd_flags 2>/dev/null"
    if command -sq rga
        set cmd_docs "[ -n \"{q}\" ] && rga --column --line-number --no-heading --color=always --smart-case -- {q} 2>/dev/null || fd --type f -e pdf -e docx -e doc -e xlsx -e pptx -e epub -e ipynb -e md $fd_flags 2>/dev/null || true"
    end
    set -l cmd_git "git status --porcelain 2>/dev/null | sed 's/^...//' || true"

    # Unified change reload command dynamically evaluating active mode
    set -l change_reload "mode=\$(cat $state_file 2>/dev/null || echo code); if [ \"\$mode\" = \"docs\" ]; then $cmd_docs; else $cmd_code; fi"

    # Define atomic transition actions for each mode
    set -l act_code "execute-silent(echo code > $state_file)+change-prompt(1. code> )+disable-search+reload($cmd_code)+change-preview($preview_script {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)"
    set -l act_files "execute-silent(echo files > $state_file)+change-prompt(2. files> )+enable-search+unbind(change)+reload($cmd_files)+change-preview($preview_script {1})+change-preview-window(right:70%,border-rounded)"
    set -l act_dirs "execute-silent(echo dirs > $state_file)+change-prompt(3. dirs> )+enable-search+unbind(change)+reload($cmd_dirs)+change-preview($preview_script {1})+change-preview-window(right:70%,border-rounded)"
    set -l act_hidden "execute-silent(echo hidden > $state_file)+change-prompt(4. hidden> )+enable-search+unbind(change)+reload($cmd_hidden)+change-preview($preview_script {1})+change-preview-window(right:70%,border-rounded)"
    set -l act_binary "execute-silent(echo binary > $state_file)+change-prompt(5. binary> )+enable-search+unbind(change)+reload($cmd_binary)+change-preview($preview_script {1})+change-preview-window(right:70%,border-rounded)"
    set -l act_docs "execute-silent(echo docs > $state_file)+change-prompt(6. docs> )+disable-search+reload($cmd_docs)+change-preview($preview_script {1} {2})+change-preview-window(right:70%,border-rounded,+{2}+3/3,~3)+rebind(change)"
    set -l act_git "execute-silent(echo git > $state_file)+change-prompt(7. git> )+enable-search+unbind(change)+reload($cmd_git)+change-preview($preview_script {1})+change-preview-window(right:70%,border-rounded)"

    # Path to mode switcher script
    set -l mode_script "$__fish_config_dir/bin/fzf-mode.sh"
    if not test -x "$mode_script"
        set mode_script "/Users/x0r/.config/fish/bin/fzf-mode.sh"
    end

    # Header status banner showing hotkeys directly in the unified interface
    set -l header_status "Modes: [Ctrl+R: Code] [Ctrl+F: Files] [Ctrl+D: Dirs] [Ctrl+H: Hidden] [Ctrl+B: Binary] [Ctrl+A: Docs] [Ctrl+G: Git] | Cycle: [Alt+S: Engine] [Alt+T: Type]"

    # Resolve startup parameters based on initial mode
    set -l initial_fzf_cmd
    set -l initial_prompt "2. files> "
    set -l initial_preview "$preview_script {1}"
    set -l initial_preview_window "right:70%,border-rounded"
    set -l is_disabled 0
    set -l start_bind "--bind=start:unbind(change)"

    switch $current_mode
        case code
            set initial_prompt "1. code> "
            set initial_fzf_cmd "if [ -n \"$initial_query\" ]; then rg $rg_flags -- \"$initial_query\" || true; else true; fi"
            set initial_preview "$preview_script {1} {2}"
            set initial_preview_window "right:70%,border-rounded,+{2}+3/3,~3"
            set is_disabled 1
            set start_bind "--bind=start:rebind(change)"
        case files
            set initial_prompt "2. files> "
            set initial_fzf_cmd "$cmd_files"
            set initial_preview "$preview_script {1}"
        case dirs
            set initial_prompt "3. dirs> "
            set initial_fzf_cmd "$cmd_dirs"
            set initial_preview "$preview_script {1}"
        case hidden
            set initial_prompt "4. hidden> "
            set initial_fzf_cmd "$cmd_hidden"
            set initial_preview "$preview_script {1}"
        case binary bin
            set initial_prompt "5. binary> "
            set initial_fzf_cmd "$cmd_binary"
            set initial_preview "$preview_script {1}"
        case docs
            set initial_prompt "6. docs> "
            set initial_fzf_cmd "$cmd_docs"
            set initial_preview "$preview_script {1} {2}"
            set initial_preview_window "right:70%,border-rounded,+{2}+3/3,~3"
            set is_disabled 1
            set start_bind "--bind=start:rebind(change)"
        case git
            set initial_prompt "7. git> "
            set initial_fzf_cmd "$cmd_git"
            set initial_preview "$preview_script {1}"
    end

    # Construct complete, strictly validated native FZF option list
    set -l fzf_opts \
        --ansi \
        --multi \
        --delimiter=: \
        --border=rounded \
        "--border-label=❱❱ Universal Search Engine ❱❱" \
        --border-label-pos=-5 \
        "--prompt=$initial_prompt" \
        "--header=$header_status" \
        "--preview=$initial_preview" \
        "--preview-window=$initial_preview_window" \
        $start_bind \
        "--bind=change:reload($change_reload)" \
        "--bind=ctrl-r:$act_code" \
        "--bind=alt-1:$act_code" \
        "--bind=ctrl-f:$act_files" \
        "--bind=alt-2:$act_files" \
        "--bind=ctrl-d:$act_dirs" \
        "--bind=alt-3:$act_dirs" \
        "--bind=ctrl-h:$act_hidden" \
        "--bind=alt-4:$act_hidden" \
        "--bind=ctrl-b:$act_binary" \
        "--bind=alt-5:$act_binary" \
        "--bind=ctrl-a:$act_docs" \
        "--bind=alt-6:$act_docs" \
        "--bind=ctrl-g:$act_git" \
        "--bind=alt-7:$act_git" \
        "--bind=alt-s:transform($mode_script cycle-engine $state_file $preview_script)" \
        "--bind=alt-t:transform($mode_script cycle-type $state_file $preview_script)" \
        "--bind=ctrl-t:transform($mode_script cycle-type $state_file $preview_script)" \
        "--bind=?:toggle-preview" \
        "--bind=alt-[:toggle-preview" \
        "--bind=alt-]:change-preview-window(70%|45%,down,border-top|45%,up,border-bottom|hidden)+show-preview" \
        "--bind=alt-w:toggle-preview-wrap" \
        "--bind=alt-k:preview-up" \
        "--bind=alt-j:preview-down" \
        "--bind=alt-page-up:preview-page-up" \
        "--bind=alt-page-down:preview-page-down" \
        "--bind=ctrl-s:toggle-sort" \
        "--bind=alt-a:toggle-all" \
        "--bind=ctrl-y:execute-silent(printf \"%s\" {+} | pbcopy)+abort" \
        "--bind=ctrl-o:execute-silent(open {1})+abort" \
        "--bind=alt-enter:execute-silent(open {1})+abort" \
        "--bind=ctrl-v:execute(code {+})+abort" \
        "--color=fg:#5b5d5e,fg+:#2aff00,bg:#000000,bg+:#000000" \
        "--color=hl:#5f87af,hl+:#5fd7ff,info:#afaf87,marker:#001cba" \
        "--color=prompt:#d7005f,spinner:#9dff00,pointer:#48ff00,header:#87afaf" \
        "--color=border:#d000ff,separator:#95ff00,label:#aeaeae,query:#d9d9d9"

    if test -n "$initial_query"
        set -a fzf_opts "--query=$initial_query"
    end

    if test "$is_disabled" -eq 1
        set -a fzf_opts --disabled
    end

    # Launch FZF in interactive mode
    set -l selected_raw (eval $initial_fzf_cmd | fzf $fzf_opts)

    # Read the final active mode to perform mode-aware actions
    set -l final_mode (cat "$state_file" 2>/dev/null; or echo "files")
    command rm -f "$state_file" 2>/dev/null

    # If search was aborted with ESC or Ctrl+C, exit cleanly
    if test -z "$selected_raw"
        return 0
    end

    # Handle direct clipboard copy flag
    if set -q _flag_copy
        printf "%s\n" $selected_raw | pbcopy
        echo "📋 Copied to clipboard"
        return 0
    end

    # Handle direct open flag
    if set -q _flag_open
        for line in $selected_raw
            set -l target_file (string split -f1 ":" -- "$line")
            open "$target_file"
        end
        return 0
    end

    # Resolve editor command
    set -l editor_cmd "nvim"
    if set -q _flag_editor
        set editor_cmd $_flag_editor
    else if set -q EDITOR
        set editor_cmd $EDITOR
    end

    # Mode-Aware Smart Action Dispatcher
    set -l files_to_open
    for line in $selected_raw
        # 1. Directory Selection (in dirs mode or if target is a directory) -> CD directly
        if test "$final_mode" = "dirs"; or test -d "$line"
            builtin cd "$line"
            echo "📁 Navigated to: $line"
            return 0
        end

        # 2. Code / Docs Content Match: "path:line:col:content"
        if string match -qr '^([^:]+):([0-9]+)(:([0-9]+))?:?.*$' -- "$line"
            set -l tokens (string split ":" -- "$line")
            set -l file_target $tokens[1]
            set -l line_number $tokens[2]
            set -l col_number 1
            if test (count $tokens) -ge 3; and string match -qr '^[0-9]+$' -- "$tokens[3]"
                set col_number $tokens[3]
            end

            # Open at exact line and column
            if test "$editor_cmd" = "nvim" -o "$editor_cmd" = "vim"
                $editor_cmd "+call cursor($line_number, $col_number)" "$file_target"
                return 0
            else if test "$editor_cmd" = "code"
                code -g "$file_target:$line_number:$col_number"
                return 0
            else
                $editor_cmd "+$line_number" "$file_target"
                return 0
            end
        end

        # 3. Git Status Match (Strip leading porcelain status flags e.g. "M  file")
        if test "$final_mode" = "git"
            set -l cleaned_file (string replace -r '^[MADRCU?! ]{1,3}\s*' '' -- "$line")
            if test -e "$cleaned_file"
                set -a files_to_open "$cleaned_file"
                continue
            end
        end

        # 4. Binary Executable Match
        if test "$final_mode" = "binary" -o "$final_mode" = "bin"; and test -x "$line"; and not test -d "$line"
            echo "⚙️ Executing: $line"
            eval "$line"
            return 0
        end

        # 5. Standard File Collection
        set -a files_to_open "$line"
    end

    # Open collected files in editor
    if test (count $files_to_open) -gt 0
        $editor_cmd $files_to_open
    end
end
