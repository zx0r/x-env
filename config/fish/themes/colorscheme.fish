# ---
# schema: "mdd-node-v1"
# id: "themes/colorscheme.fish"
# title: "Graffiti ZX0R Color Palette"
# layer: "UX / UI (30-39)"
# responsibility: "Defines the command line syntax coloring, completion pager theme, and path highlighting colors"
# dependencies: []
# backlinks: ["config.fish"]
# created_at: "2026-06-27"
# updated_at: "2026-06-27"
# tags: ["colorscheme", "theme", "graffiti", "palette"]
# ---

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Graffiti ZX0R Color Palette Reference (Coordinated with Nike/Supreme/Off-White Wall)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Palette Hex Codes:
#   • Black (Background): #000000 / #050508
#   • Gray (Concrete Base):#888888
#   • Orange (Accent):     #ff7700 / #ffaa00
#   • Blue (ZX0R Tag):     #00b4ff
#   • Cyan (Highlight):    #00ffff
#   • Red (Supreme):       #ff003c / #ff2a2a
#   • Green (Active/Run):  #00ff66 / #00ff00
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Base Environment Configuration
set -g fish_term256 1

# 2. Command Line Syntax Coloring
set -g fish_color_normal e0f7fc # Default text / Ice blue-white
set -g fish_color_command 00ff66 # Commands / Neon green (Run detail)
set -g fish_color_param 00ffff # Parameters / Cyan
set -g fish_color_quote ffaa00 # Strings / Bright orange
set -g fish_color_comment 888888 # Comments / Concrete gray
set -g fish_color_operator ff7700 # Operators / Neon orange (ZX0R gradient)
set -g fish_color_escape ff7700 # Escape characters / Neon orange
set -g fish_color_redirection 00b4ff # Redirection operator / ZX0R blue

# 3. Command Line State & Highlighting
set -g fish_color_autosuggestion 555555 # Autosuggestions / Dark gray
set -g fish_color_match 00ff66 # Matching parenthesis / Neon green
set -g fish_color_search_match bryellow --background=000000 # Search match highlighting
set -g fish_color_selection 00b4ff --background=222222 # Visual mode selection / ZX0R blue
set -g fish_color_cancel ff003c # Cancel command indicator / Supreme red
set -g fish_color_end ff003c # Process delimiters / Supreme red
set -g fish_color_error ff003c # Syntax error indicator / Supreme red

# 4. Path Highlighting Colors
set -g fish_color_valid_path 00ff66 --underline # Valid path / Neon green underlined
set -g fish_color_valid_path_file 00ffff # Valid file / Cyan
set -g fish_color_valid_path_dir 00b4ff # Valid directory / ZX0R blue

# 5. Shell Prompt Customization
set -g fish_color_user brgreen # Prompt username / Bright green
set -g fish_color_host 85ad82 # Prompt hostname / Sage green
set -g fish_color_host_remote yellow # Remote host / Yellow
set -g fish_color_status red # Last command status / Red
set -g fish_color_history_current --bold # Current history item indicator
set -g fish_color_cwd 00b4ff # Current directory / ZX0R blue
set -g fish_color_cwd_root ff003c # Root current directory / Supreme red
set -g fish_color_pwd_bg 000000 # Directory background / Black
set -g fish_color_pwd_dir_bg 000000 # Directory background / Black

# 6. Autocompletion Pager Customization (fish_pager)
set -g fish_pager_color_completion 808080 # Pager completion text / Gray
set -g fish_pager_color_prefix 00ffff --bold --underline # Pager prefix highlight / Cyan
set -g fish_pager_color_progress 00ff66 # Pager progress bar / Neon green
set -g fish_pager_color_description ffaa00 yellow # Pager description / Warm orange
set -g fish_pager_color_selected_background --background=222222 # Selected item background / Dark concrete gray
set -g fish_pager_color_selected_prefix 00b4ff # Selected item prefix / ZX0R blue
set -g fish_pager_color_selected_completion 00ffff # Selected item completion / Cyan
