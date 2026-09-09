# ---
# schema: "mdd-node-v1"
# id: "conf.d/10-runtimes.fish"
# title: "Self-Healing Runtime Cache Engine"
# layer: "Infrastructure (10-19)"
# responsibility: "Manages compiled static initializers for Mise, Starship, Zoxide, Atuin, and FZF with fast-path sourcing and parallel invalidation"
# dependencies: ["conf.d/01-variables.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["cache", "runtimes", "performance", "mise", "shims"]
# ---

# Defensive check: These tools are only relevant for interactive shell usage
status is-interactive; or return

# 1. Establish cache namespace
set -l static_cache_directory_path "$XDG_CACHE_HOME/fish/static_init"
test -d "$static_cache_directory_path"; or mkdir -p "$static_cache_directory_path"

# Fast-path check: If all compiled caches exist, bypass binary inspection entirely
if not test -f "$static_cache_directory_path/starship.fish"
    or not test -f "$static_cache_directory_path/zoxide.fish"
    or not test -f "$static_cache_directory_path/atuin.fish"
    or not test -f "$static_cache_directory_path/fzf.fish"

    set -l cache_pids

    # --- Starship (Prompt Engine) ---
    if type -q starship
        if not test -f "$static_cache_directory_path/starship.fish"
            starship init fish --print-full-init >"$static_cache_directory_path/starship.fish" &
            set -a cache_pids $last_pid
        end
    end

    # --- Zoxide (Fuzzy Navigation Engine) ---
    if type -q zoxide
        if not test -f "$static_cache_directory_path/zoxide.fish"
            zoxide init fish >"$static_cache_directory_path/zoxide.fish" &
            set -a cache_pids $last_pid
        end
    end

    # --- Atuin (Fuzzy History Engine) ---
    if type -q atuin
        if not test -f "$static_cache_directory_path/atuin.fish"
            atuin init fish >"$static_cache_directory_path/atuin.fish" &
            set -a cache_pids $last_pid
        end
    end

    # --- FZF Key Bindings ---
    if type -q fzf
        if not test -f "$static_cache_directory_path/fzf.fish"
            fzf --fish >"$static_cache_directory_path/fzf.fish" &
            set -a cache_pids $last_pid
        end
    end

    if set -q cache_pids[1]
        wait $cache_pids
        # Post-process atuin.fish if regenerated to bypass 'atuin uuid' spawn
        if test -f "$static_cache_directory_path/atuin.fish"
            set -l atuin_content (cat "$static_cache_directory_path/atuin.fish")
            set -l native_uuid_code 'printf "%04x%04x-%04x-%04x-%04x-%04x%04x%04x" (random 0 65535) (random 0 65535) (random 0 65535) (random 16384 20479) (random 32768 49151) (random 0 65535) (random 0 65535) (random 0 65535)'
            set -l patched_content (string replace 'atuin uuid' "$native_uuid_code" $atuin_content)
            printf "%s\n" $patched_content > "$static_cache_directory_path/atuin.fish"
        end
    end
end

# 2. Source compiled static runtimes
if test -f "$static_cache_directory_path/starship.fish"
    source "$static_cache_directory_path/starship.fish"
end

if test -f "$static_cache_directory_path/zoxide.fish"
    source "$static_cache_directory_path/zoxide.fish"
end

if test -f "$static_cache_directory_path/atuin.fish"
    source "$static_cache_directory_path/atuin.fish"
    # Ensure hotkey triggers history search cleanly
    bind \cr _atuin_search
    bind -M insert \cr _atuin_search
end


