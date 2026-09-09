# ---
# schema: "mdd-node-v1"
# id: "functions/kitty.fish"
# title: "Kitty Terminal Configurator"
# layer: "Functions"
# responsibility: "Helper utilities to reload kitty colors and adjust opacity, blur, and themes"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-06-25"
# last_commit: "f4adbd9652c78a01f562b7194602f3fa10eeea80"
# tags: ["terminal", "kitty"]
# ---

function kitty_macos_keys
    set -l KITTY_CONF "$XDG_CONFIG_HOME/kitty/kitty.conf"

    function update_kitty
        kitty @ set-colors --all --configured
    end

    function adjust_opacity
        set -l opacity (seq 0.1 0.1 1 | fzf --prompt="Select Opacity: ")
        if test -n "$opacity"
            sed -i '' -E "s/^background_opacity\s+.*/background_opacity $opacity/" $KITTY_CONF
            update_kitty
        end
    end

    function adjust_blur
        set -l blur_level (echo -e "off\nlow\nmedium\nhigh" | fzf --prompt="Select Blur Level: ")
        if test -n "$blur_level"
            sed -i '' -E "s/^background_blur\s+.*/background_blur $blur_level/" $KITTY_CONF
            update_kitty
        end
    end

    function switch_theme
        set -l theme (ls $XDG_CONFIG_HOME/kitty/themes | fzf --prompt="Select Theme: ")
        if test -n "$theme"
            sed -i '' -E "s/^include themes\/.*/include themes\/$theme/" $KITTY_CONF
            update_kitty
        end
    end

    function change_wallpaper
        set -l wallpaper_path "$HOME/documents/Wallpapers/"
        set -l wallpaper (find $wallpaper_path -type f | fzf --prompt="Select Wallpaper: ")
        if test -n "$wallpaper"
            sed -i '' -E "s|^background_image\s+.*|background_image $wallpaper|" $KITTY_CONF
            update_kitty
        end
    end

    echo "Applying macOS keybindings..."
    echo "
map cmd+[ no_op
map cmd+] no_op
map cmd+- no_op
map cmd+= no_op
map cmd+shift+t no_op
map cmd+shift+w no_op

map cmd+[ send_text all \033[31~
map cmd+] send_text all \033[32~
map cmd+- send_text all \033[33~
map cmd+= send_text all \033[34~
map cmd+shift+t send_text all \033[35~
map cmd+shift+w send_text all \033[36~
" >>$KITTY_CONF

    update_kitty
end
