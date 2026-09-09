#!/bin/bash
# A script to cycle through rainbow colors for Kitty border

kitty_config="$HOME/.config/kitty/kitty.conf"

# Define rainbow colors
colors=("#FF0000" "#FF7F00" "#FFFF00" "#00FF00" "#0000FF" "#4B0082" "#8B00FF")

while true; do
  for color in "${colors[@]}"; do
    sed -i "/^active_border_color/c\active_border_color $color" "$kitty_config"
    pkill -USR1 kitty # Reload Kitty config
    sleep 0.5         # Adjust speed of transition
  done
done
