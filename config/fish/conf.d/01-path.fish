# ---
# schema: "mdd-node-v1"
# id: "conf.d/01-path.fish"
# title: "Vectorized Native PATH Sanitization"
# layer: "Foundation (00-09)"
# responsibility: "Normalizes, sanitizes, and exports system search paths using C++ builtins. Mise shims are the single source of truth for all managed runtimes."
# dependencies: ["conf.d/00-xdg.fish"]
# backlinks: ["config.fish", "conf.d/02-brew.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["path", "mise", "shims", "docker"]
# ---

# 1. High-priority search paths to prepend (in order of priority: first is highest)
# Listed in reverse order of priority because prepending them one by one in a loop reverses them.
#
# ARCHITECTURAL INVARIANT: mise shims (~/.local/share/mise/shims) MUST be listed LAST here
# (= highest priority in the final PATH) so that all mise-managed runtimes (bun, node, go, etc.)
# resolve through the shim dispatcher — NOT via hardcoded installs/* paths.
# This is the single source of truth for runtime version management.
set -l mise_shims_dir "$HOME/.local/share/mise/shims"
set -l docker_bin_dir "$HOME/.docker/bin"
set -l prepend_paths "$BOB_HOME" "$docker_bin_dir" /opt/homebrew/sbin /opt/homebrew/bin "$mise_shims_dir"

# 2. Essential default system paths that must always be present in PATH (fallback priority)
set -l default_system_paths /usr/local/bin /usr/bin /bin /usr/sbin /sbin /usr/local/sbin

# 3. Deprecated system paths to exclude from search environments
set -l deprecated_system_paths "$HOME/.cargo/bin" "$HOME/.gem/ruby/4.0.0/bin" /opt/homebrew/opt/ruby/bin

# 4. Vectorized Path Sanitization Engine
set -l path_variables_to_sanitize PATH __MISE_ORIG_PATH
for path_variable_name in $path_variables_to_sanitize
    set -q $path_variable_name; or continue
    
    # Extract current paths from variable
    set -l current_paths $$path_variable_name

    # If parsing PATH, guarantee prepended paths and default system paths are present in correct order
    if test "$path_variable_name" = "PATH"
        # Prepend high-priority paths in loop
        for p in $prepend_paths
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
