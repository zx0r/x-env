# Semantic PTY for LLM / Zero-Cognitive-Load
set -g status off
set -gw pane-border-lines simple

# ASCII-only переопределения (инжектим переменные темы, как в драфте)
set -g @pane   "#[default,bg=#{@ui_surface},fg=#{@ui_accent}] P:#[fg=#{@ui_fg_muted}]#P"
set -g @zoom   "#[default,bg=#{@ui_surface},fg=#{@ui_highlight}]#{?window_zoomed_flag, [Z],}"
set -g @prefix "#[bold]#{?client_prefix,#[fg=#{@ui_success}]CMD ,}"
set -g @status_project "#[noreverse,bold,fg=#{@ui_fg_muted}] DIR: #{b:pane_current_path}"
set -gw pane-border-format '#[align=left]#{?pane_active, [*] , [ ] }#[bold]#{pane_current_command} #[nobold]#{pane_tty} #{?window_zoomed_flag,[Z],} #P '
