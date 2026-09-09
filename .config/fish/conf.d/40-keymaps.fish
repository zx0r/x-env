# ---
# schema: "mdd-node-v1"
# id: "conf.d/40-keymaps.fish"
# title: "Keyboard Mappings & Vi Widget Bindings"
# layer: "Input & Mappings (40-49)"
# responsibility: "Configures Vi-mode bindings, clipboard integrations, and custom fuzzy-finder interactive widgets"
# dependencies: ["conf.d/30-ux.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["keymaps", "bindings", "vi-mode", "widgets"]
# ---

# Defensive check: Keybindings are only relevant for interactive shell usage
status is-interactive; or return

# 1. Enable Vi Mode Keybindings
# This triggers the initialization function which reads the cursor variables from 30-ux.fish
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_escape_delay_ms 10 # Instant Escape key behavior in vi insert mode

# 2. Custom Key Bindings Registry (Evaluated by Fish after conf.d loading)
function fish_user_key_bindings
    # 1. Enable default key bindings in insert mode for hybrid Vi ergonomics
    fish_default_key_bindings -M insert
    fish_vi_key_bindings --no-erase insert
    fish_vi_cursor

    # 2. System Clipboard Integration (y/yy/p in Vi modes)
    bind -M visual -m default y 'fish_clipboard_copy; commandline -f end-selection repaint-mode'
    bind yy fish_clipboard_copy
    bind p fish_clipboard_paste

    # 3. Zoxide Interactive Jumper (Alt+Z)
    if type -q zi
        bind \e\z zi
        bind -M insert \e\z zi
    end

    # 4. FZF Interactive Widgets
    if type -q fzf
        # 1. Files search (Ctrl+F)
        bind \cf fzf-file-widget
        bind -M insert \cf fzf-file-widget
        # CSI u protocol Ctrl+f (\e[102;5u)
        bind \e\[102\;5u fzf-file-widget
        bind -M insert \e\[102\;5u fzf-file-widget

        # 2. Directories search and CD (Alt+C)
        bind \ec fzf-cd-widget
        bind -M insert \ec fzf-cd-widget
        # macOS Option+C character output fallback (ç)
        bind ç fzf-cd-widget
        bind -M insert ç fzf-cd-widget
        # Cyrillic layout Alt+C (Russian keyboard 'с')
        bind \eс fzf-cd-widget
        bind -M insert \eс fzf-cd-widget
        bind \eС fzf-cd-widget
        bind -M insert \eС fzf-cd-widget
        # CSI u protocol Alt+c (\e[99;3u) and Alt+C / Cyrillic layout support
        bind \e\[99\;3u fzf-cd-widget
        bind -M insert \e\[99\;3u fzf-cd-widget
        bind \e\[99\:3u fzf-cd-widget
        bind -M insert \e\[99\:3u fzf-cd-widget
        bind \e\[1089\;3u fzf-cd-widget
        bind -M insert \e\[1089\;3u fzf-cd-widget

        # 3. Active processes search (Ctrl+Alt+P)
        bind \e\cp fzf-process-widget
        bind -M insert \e\cp fzf-process-widget
        # CSI u protocol Ctrl+Alt+p (\e[112;6u or \e[112;7u)
        bind \e\[112\;6u fzf-process-widget
        bind -M insert \e\[112\;6u fzf-process-widget
        bind \e\[112\;7u fzf-process-widget
        bind -M insert \e\[112\;7u fzf-process-widget

        # 4. Git status files search (Ctrl+G)
        bind \cg fzf-git-widget
        bind -M insert \cg fzf-git-widget
        # CSI u protocol Ctrl+g (\e[103;5u)
        bind \e\[103\;5u fzf-git-widget
        bind -M insert \e\[103\;5u fzf-git-widget
    end

    # Atuin Smart History Search
    if functions -q _atuin_search
        # Rebind Ctrl+R in normal, insert, and visual modes
        bind \cr _atuin_search
        bind -M insert \cr _atuin_search
        bind -M visual \cr _atuin_search
    end

    if functions -q _atuin_bind_up
        # Bind Up arrow keys (compatible with Fish 4.x key names)
        bind up _atuin_bind_up
        bind \eOA _atuin_bind_up
        bind \e\[A _atuin_bind_up
        bind -M insert up _atuin_bind_up
        bind -M insert \eOA _atuin_bind_up
        bind -M insert \e\[A _atuin_bind_up
    end
end
