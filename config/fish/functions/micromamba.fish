# ---
# schema: "mdd-node-v1"
# id: "functions/micromamba.fish"
# title: "Lazy Micromamba Initializer & Command Wrapper"
# layer: "Functions"
# responsibility: "Lazily initializes micromamba environment variables, adds condabin path, and executes micromamba command, preventing startup hooks latency"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["micromamba", "conda", "lazy-load", "performance"]
# ---

function micromamba --description "Wrapper for micromamba to lazily set environment variables and prompts"
    # Lazy bootstrap micromamba environment variables on first call
    if not set -q MAMBA_SHLVL
        set -gx MAMBA_SHLVL "0"
        set -gx MAMBA_ROOT_PREFIX "$HOME/.local/share/mamba"
        set -gx MAMBA_EXE "/Users/x0r/.local/share/mise/installs/micromamba/latest/bin/micromamba"
        fish_add_path --move $MAMBA_ROOT_PREFIX/condabin
    end

    # Run the command wrapper
    if test (count $argv) -lt 1 || contains -- --help $argv
        $MAMBA_EXE $argv
    else
        set -l cmd $argv[1]
        set -e argv[1]
        switch $cmd
            case activate deactivate
                # Dynamically define micromamba's prompt alteration helpers
                __mamba_define_prompt_functions
                $MAMBA_EXE shell $cmd --shell fish $argv | source || return $status
            case install update upgrade remove uninstall
                $MAMBA_EXE $cmd $argv || return $status
                $MAMBA_EXE shell reactivate --shell fish | source || return $status
            case '*'
                $MAMBA_EXE $cmd $argv
        end
    end
end

function __mamba_define_prompt_functions
    if functions -q __mamba_add_prompt; return; end
    
    function __mamba_add_prompt
        if set -q CONDA_PROMPT_MODIFIER
            set_color -o green
            echo -n $CONDA_PROMPT_MODIFIER
            set_color normal
        end
    end

    if functions -q fish_prompt
        if not functions -q __fish_prompt_orig
            functions -c fish_prompt __fish_prompt_orig
        end
        functions -e fish_prompt
    else
        function __fish_prompt_orig
        end
    end

    function return_last_status
        return $argv
    end

    function fish_prompt
        set -l last_status $status
        if set -q MAMBA_LEFT_PROMPT
            __mamba_add_prompt
        end
        return_last_status $last_status
        __fish_prompt_orig
    end

    if functions -q fish_right_prompt
        if not functions -q __fish_right_prompt_orig
            functions -c fish_right_prompt __fish_right_prompt_orig
        end
        functions -e fish_right_prompt
    else
        function __fish_right_prompt_orig
        end
    end

    function fish_right_prompt
        if not set -q MAMBA_LEFT_PROMPT
            __mamba_add_prompt
        end
        __fish_right_prompt_orig
    end
end
