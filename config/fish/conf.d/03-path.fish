# ---
# schema: "mdd-node-v1"
# id: "conf.d/03-path.fish"
# title: "Vectorized Native PATH Sanitization"
# layer: "Foundation (00-09)"
# responsibility: "Normalizes, sanitizes, and exports system search paths using C++ builtins and unified AOT static cache. Mise shims are the single source of truth for all managed runtimes."
# dependencies: ["conf.d/00-xdg.fish", "conf.d/01-variables.fish", "conf.d/02-brew.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-04"
# last_commit: "pending"
# tags: ["path", "mise", "shims", "docker", "aot-cache"]
# ---

# 1. Fast-Path AOT Static Initialization Cache (Sub-0.1ms Zero-Syscall)
set -l path_cache "$XDG_CACHE_HOME/fish/static_init/path.fish"
if test -f "$path_cache"
    # Invalidate cache if 03-path.fish source file is newer than the cache
    if not test "$__fish_config_dir/conf.d/03-path.fish" -nt "$path_cache"
        source "$path_cache"
        return
    end
end
# 2. High-priority search paths to prepend (in order of priority: first is highest)
# Listed in reverse order of priority because prepending them one by one in a loop reverses them.
#
# ARCHITECTURAL INVARIANT: mise shims (~/.local/share/mise/shims) MUST be listed FIRST here
# (= highest priority in the final PATH) so that all mise-managed runtimes (bun, node, go, etc.)
# resolve through the shim dispatcher — NOT via hardcoded installs/* paths.
# This is the single source of truth for runtime version management.
set -l mise_shims_dir "$HOME/.local/share/mise/shims"
set -l docker_bin_dir "$HOME/.docker/bin"
set -l antigravity_bin "$HOME/.antigravity-ide/antigravity-ide/bin"
set -l prepend_paths "$mise_shims_dir" "$XDG_BIN_HOME" "$CURL_BIN" "$docker_bin_dir" "$BOB_HOME" "$antigravity_bin" /opt/homebrew/bin /opt/homebrew/sbin

# 3. Essential default system paths that must always be present in PATH (fallback priority)
set -l default_system_paths /usr/local/bin /usr/bin /bin /usr/sbin /sbin /usr/local/sbin

# 4. Deprecated system paths to exclude from search environments
set -l deprecated_system_paths "$HOME/.cargo/bin" "$HOME/.gem/ruby/4.0.0/bin" /opt/homebrew/opt/ruby/bin

# 5. Vectorized Path Sanitization Engine (Zero Forks, C++ Builtins)
set -l path_variables_to_sanitize PATH __MISE_ORIG_PATH
for path_variable_name in $path_variables_to_sanitize
    set -q $path_variable_name; or continue

    # Extract current paths from variable
    set -l current_paths $$path_variable_name

    # If parsing PATH, guarantee prepended paths and default system paths are present in correct order
    if test "$path_variable_name" = PATH
        # Prepend high-priority paths in reverse sequence so highest priority ends up at index 1
        for p in $prepend_paths[-1..1]
            if test -d "$p"
                if set -l index (contains -i -- "$p" $current_paths)
                    set -e current_paths[$index]
                end
                set current_paths "$p" $current_paths
            end
        end

        # Append default system paths as low-priority fallbacks if not already present
        for default_path in $default_system_paths
            if not contains -- $default_path $current_paths
                set -a current_paths $default_path
            end
        end
    end

    set -l sanitized_path_list

    # Native path normalization and directory validation (zero forks)
    set -l normalized_paths (path normalize $current_paths)
    set -l existing_directories (path filter -d $normalized_paths)

    for path_entry in $existing_directories
        if not contains -- $path_entry $deprecated_system_paths; and not contains -- $path_entry $sanitized_path_list
            set -a sanitized_path_list $path_entry
        end
    end
    set -gx $path_variable_name $sanitized_path_list
end

# 6. Atomically Persist to Unified AOT Cache ($XDG_CACHE_HOME/fish/static_init/path.fish)
set -l cache_dir "$XDG_CACHE_HOME/fish/static_init"
test -d "$cache_dir"; or command mkdir -p "$cache_dir"
set -l tmp_cache "$path_cache.$fish_pid"
echo "# AUTO-GENERATED PATH AOT CACHE" > "$tmp_cache"
echo "set -gx PATH "(string join " " (string escape -- $PATH)) >> "$tmp_cache"
if set -q __MISE_ORIG_PATH
    echo "set -gx __MISE_ORIG_PATH "(string join " " (string escape -- $__MISE_ORIG_PATH)) >> "$tmp_cache"
end
command mv -f "$tmp_cache" "$path_cache"
