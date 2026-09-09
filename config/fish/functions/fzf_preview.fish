# ---
# schema: "mdd-node-v1"
# id: "functions/fzf_preview.fish"
# title: "Fuzzy Finder Multi-Mode Preview Browser"
# layer: "Functions"
# responsibility: "Executes interactive fuzzy find selector with mode-switching and previews"
# dependencies: ["fzf"]
# backlinks: ["conf.d/50-fzf.fish"]
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["fzf", "preview", "browser"]
# ---

function fzf_preview
    if not command -sq fzf
        echo "Error: fzf is not installed" >&2
        return 1
    end

    set -l search_mode fzf
    set -l preview_enabled 1
    set -l find_type files

    function toggle_preview -V preview_enabled
        if test $preview_enabled -eq 1
            set preview_enabled 0
        else
            set preview_enabled 1
        end
    end

    function toggle_search_mode -V search_mode
        switch $search_mode
            case fzf
                set search_mode rg
            case rg
                set search_mode ag
            case ag
                set search_mode fzf
        end
    end

    function toggle_find_type -V find_type
        switch $find_type
            case files
                set find_type dirs
            case dirs
                set find_type hidden
            case hidden
                set find_type binary
            case binary
                set find_type files
        end
    end

    while true
        # Define search command based on mode
        switch $find_type
            case files
                set search_cmd "find . -type f"
            case dirs
                set search_cmd "find . -type d"
            case hidden
                set search_cmd "find . -type f -name '.*'"
            case binary
                set search_cmd "find . -type f -exec file {} + | grep 'binary' | cut -d: -f1"
        end

        switch $search_mode
            case fzf
                set -l selection (eval "$search_cmd" | fzf --preview="/Users/x0r/.config/fish/bin/fzf-preview.sh {1}")
            case rg
                set -l selection (rg --files | fzf --preview="/Users/x0r/.config/fish/bin/fzf-preview.sh {1}")
            case ag
                set -l selection (ag --files | fzf --preview="/Users/x0r/.config/fish/bin/fzf-preview.sh {1}")
        end

        if test -n "$selection"
            echo "Selected: $selection"
        else
            break
        end
    end
end
