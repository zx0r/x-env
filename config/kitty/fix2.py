import re

with open('kitty.conf', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove inline comments for the specific lines
content = re.sub(r'auto_reload_config 1.0.*', r'auto_reload_config 1.0', content)
content = re.sub(r'momentum_scroll 0.96.*', r'momentum_scroll 0.96', content)
content = re.sub(r'drag_threshold 3.*', r'drag_threshold 3', content)
content = re.sub(r'window_drag_tolerance 3.*', r'window_drag_tolerance 3', content)
content = re.sub(r'pixel_scroll yes.*', r'pixel_scroll yes', content)
content = re.sub(r'macos_dock_badge_on_bell yes.*', r'macos_dock_badge_on_bell yes', content)
content = re.sub(r'macos_ns_window_layer normal.*', r'macos_ns_window_layer normal', content)
content = re.sub(r'macos_use_physical_screen_frame yes.*', r'macos_use_physical_screen_frame yes', content)
content = re.sub(r'macos_fullscreen_ignore_safe_area_insets yes.*', r'macos_fullscreen_ignore_safe_area_insets yes', content)
content = re.sub(r'window_title_bar top.*', r'window_title_bar top', content)
content = re.sub(r'window_title_bar_align center.*', r'window_title_bar_align center', content)
content = re.sub(r'window_title_bar_min_windows 2.*', r'window_title_bar_min_windows 2', content)
content = re.sub(r'window_border_radius 4.*', r'window_border_radius 4', content)
content = re.sub(r'tab_bar_show_new_tab_button yes.*', r'tab_bar_show_new_tab_button yes', content)
content = re.sub(r'tab_title_max_lines 2.*', r'tab_title_max_lines 2', content)
content = re.sub(r'tab_title_wrap no.*', r'tab_title_wrap no', content)


with open('kitty.conf', 'w', encoding='utf-8') as f:
    f.write(content)
