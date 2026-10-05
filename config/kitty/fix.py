import re

with open('kitty.conf', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix auto_reload_config
content = re.sub(r'# auto_reload_config.*', r'auto_reload_config 1.0                           # Hot-reload on save', content)

# Fix momentum_scroll
content = re.sub(r'momentum_scroll yes', r'momentum_scroll 0.96', content)

# Fix drag_threshold
content = re.sub(r'drag_threshold 3\.0', r'drag_threshold 3', content)

# Fix window_drag_tolerance
content = re.sub(r'window_drag_tolerance 3\.0', r'window_drag_tolerance 3', content)

# Fix ab_* typos
content = re.sub(r'ab_bar_show_new_tab_button', r'tab_bar_show_new_tab_button', content)
content = re.sub(r'ab_title_max_lines', r'tab_title_max_lines', content)
content = re.sub(r'ab_title_wrap', r'tab_title_wrap', content)
content = re.sub(r'# ab_bar_filter', r'# tab_bar_filter', content)

with open('kitty.conf', 'w', encoding='utf-8') as f:
    f.write(content)
