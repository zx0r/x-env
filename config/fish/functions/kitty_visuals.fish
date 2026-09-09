# ---
# schema: "mdd-node-v1"
# id: "functions/kitty_visuals.fish"
# title: "Kitty Terminal Appearance Configurator"
# layer: "Functions"
# responsibility: "Interactive configuration tool for Kitty terminal settings (blur, opacity, themes, wallpaper, keymaps)"
# dependencies: ["kitty", "fzf", "sed"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["kitty", "terminal", "macos", "utility"]
# ---

function kitty_visuals --description "Interactive Kitty terminal appearance configurator"
    if not command -sq fzf
        echo "Error: 'fzf' is required but not installed." >&2
        return 1
    end

    set -l KITTY_CONF "$XDG_CONFIG_HOME/kitty/kitty.conf"
    if not test -f "$KITTY_CONF"
        echo "Error: Kitty configuration file not found at $KITTY_CONF" >&2
        return 1
    end

    function update_kitty
        echo "Reloading Kitty configuration..."
        kitty @ set-colors --all --configured 2>/dev/null; or echo "Note: Kitty remote control not enabled or terminal not active."
    end

    function set_blur -S
        set -l blur_level (echo -e "off\nlow\nmedium\nhigh" | fzf --prompt="Select Blur Level: ")
        if test -n "$blur_level"
            echo "Setting blur to $blur_level..."
            sed -i '' -E "s/^background_blur\s+.*/background_blur $blur_level/" "$KITTY_CONF"
            update_kitty
        end
    end

    function set_opacity -S
        set -l opacity (seq 0.1 0.1 1 | fzf --prompt="Select Opacity: ")
        if test -n "$opacity"
            echo "Setting opacity to $opacity..."
            sed -i '' -E "s/^background_opacity\s+.*/background_opacity $opacity/" "$KITTY_CONF"
            update_kitty
        end
    end

    function set_theme -S
        set -l themes_dir "$XDG_CONFIG_HOME/kitty/themes"
        if not test -d "$themes_dir"
            echo "Error: Themes directory not found at $themes_dir" >&2
            return 1
        end

        set -l theme (ls "$themes_dir" | fzf --prompt="Select Theme: ")
        if test -n "$theme"
            echo "Setting theme to $theme..."
            sed -i '' -E "s/^include themes\/.*/include themes\/$theme/" "$KITTY_CONF"
            update_kitty
        end
    end

    function set_wallpaper -S
        set -l wallpaper_dir "$HOME/Pictures/Wallpapers"
        if not test -d "$wallpaper_dir"
            echo "Error: Wallpapers directory not found at $wallpaper_dir" >&2
            return 1
        end

        set -l wallpaper (find "$wallpaper_dir" -type f 2>/dev/null | fzf --prompt="Select Wallpaper: ")
        if test -n "$wallpaper"
            echo "Setting wallpaper to $wallpaper..."
            sed -i '' -E "s|^background_image\s+.*|background_image $wallpaper|" "$KITTY_CONF"
            update_kitty
        end
    end

    function set_macos_keys -S
        if grep -q "cmd+c copy_to_clipboard" "$KITTY_CONF" 2>/dev/null
            echo "macOS keybindings are already applied in $KITTY_CONF."
            return
        end

        echo "Applying macOS keybindings..."
        echo "
map cmd+c copy_to_clipboard
map cmd+v paste_from_clipboard
map cmd+t new_tab
map cmd+n new_window
map cmd+w close_tab
map cmd+q quit
" >>"$KITTY_CONF"
        update_kitty
    end

    set -l choice (echo -e "Blur\nOpacity\nTheme\nWallpaper\nmacOS Keybindings" | fzf --prompt="Choose Option: ")

    switch "$choice"
        case Blur
            set_blur
        case Opacity
            set_opacity
        case Theme
            set_theme
        case Wallpaper
            set_wallpaper
        case "macOS Keybindings"
            set_macos_keys
        case '*'
            echo "No valid selection."
    end
end

