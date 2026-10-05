# ==============================================================================
#  DOMAIN: AOT CACHE COMPILATION (INFRASTRUCTURE)
#  RESPONSIBILITY: GENERATES ZERO-OVERHEAD JIT FRONTEND FOR CLI TOOLS
#  WARNING: CRITICAL PATH - DO NOT DELETE
# ==============================================================================

# ---
# schema: "mdd-node-v1"
# id: "functions/x_runtimes_build.fish"
# title: "AOT Compiler for Runtimes"
# responsibility: "Generates zero-overhead JIT frontend and monolithic cache for CLI tools"
# updated_at: "2026-10-04"
# ---

function x_runtimes_build --description "AOT Compiler for Shell Runtimes"
    set -l cache_dir "$XDG_CACHE_HOME/fish/static_init"
    command mkdir -p "$cache_dir"
    
    set -l frontend_file "$cache_dir/frontend.fish"
    set -l tmp_frontend "$frontend_file.$fish_pid"
    
    # 1. Start generation of frontend
    echo "# AUTO-GENERATED JIT FRONTEND" > "$tmp_frontend"
    echo "set -g __x_runtimes_loaded 1" >> "$tmp_frontend"
    
    set -l invalidation_checks ""
    set -l bg_pids
    
    # ---------------------------------------------------------
    # REGISTRY DEFINITIONS (Atomic Generation)
    # ---------------------------------------------------------
    
    # 1. Starship
    if set -l bin_path (command -s starship)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"\$X_RUNTIMES_FRONTEND\""
        begin
            starship init fish --print-full-init > "$cache_dir/starship.fish.$fish_pid"
            and command mv "$cache_dir/starship.fish.$fish_pid" "$cache_dir/starship.fish"
        end &
        set -a bg_pids $last_pid
        
        echo "function __00_jit_starship_init --on-event fish_prompt; functions -e __00_jit_starship_init; set -lx __jit_starship 1; test -f \"$cache_dir/starship.fish\"; or x_runtimes_build; source \"$cache_dir/starship.fish\"; function starship_transient_prompt_func; starship module character; end; function starship_transient_rprompt_func; echo \"\"; end; enable_transience; end" >> "$tmp_frontend"
        echo "function fish_mode_prompt; end" >> "$tmp_frontend"
    end
    
    # 2. Zoxide
    if set -l bin_path (command -s zoxide)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"\$X_RUNTIMES_FRONTEND\""
        begin
            zoxide init fish > "$cache_dir/zoxide.fish.$fish_pid"
            and command mv "$cache_dir/zoxide.fish.$fish_pid" "$cache_dir/zoxide.fish"
        end &
        set -a bg_pids $last_pid
        
        echo "function z; set -q __jit_zoxide; and return; set -lx __jit_zoxide 1; test -f \"$cache_dir/zoxide.fish\"; or x_runtimes_build; source \"$cache_dir/zoxide.fish\"; z \$argv; end" >> "$tmp_frontend"
        echo "function zi; set -q __jit_zoxide; and return; set -lx __jit_zoxide 1; test -f \"$cache_dir/zoxide.fish\"; or x_runtimes_build; source \"$cache_dir/zoxide.fish\"; zi \$argv; end" >> "$tmp_frontend"
        echo "function __zoxide_hook --on-variable PWD; set -q __jit_zoxide; and return; set -lx __jit_zoxide 1; test -f \"$cache_dir/zoxide.fish\"; or x_runtimes_build; source \"$cache_dir/zoxide.fish\"; __zoxide_hook \$argv; end" >> "$tmp_frontend"
    end
    
    # 3. Atuin
    if set -l bin_path (command -s atuin)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"\$X_RUNTIMES_FRONTEND\""
        
        begin
            atuin init fish > "$cache_dir/atuin.fish.$fish_pid"
            set -l atuin_content (string collect < "$cache_dir/atuin.fish.$fish_pid")
            set -l atuin_array (string split \n $atuin_content)
            set -l native_uuid_code 'printf "%04x%04x-%04x-%04x-%04x-%04x%04x%04x" (random 0 65535) (random 0 65535) (random 0 65535) (random 16384 20479) (random 32768 49151) (random 0 65535) (random 0 65535) (random 0 65535)'
            set -l patched_content (string replace 'atuin uuid' "$native_uuid_code" $atuin_array)
            set patched_content (string match -v '*prepare-search-index*' $patched_content)
            printf "%s\n" $patched_content > "$cache_dir/atuin.fish.$fish_pid.patched"
            command mv "$cache_dir/atuin.fish.$fish_pid.patched" "$cache_dir/atuin.fish"
            command rm -f "$cache_dir/atuin.fish.$fish_pid"
        end &
        set -a bg_pids $last_pid
        
        echo "function _atuin_search; set -q __jit_atuin; and return; set -lx __jit_atuin 1; test -f \"$cache_dir/atuin.fish\"; or x_runtimes_build; source \"$cache_dir/atuin.fish\"; _atuin_search \$argv; end" >> "$tmp_frontend"
        echo "function _atuin_bind_up; set -q __jit_atuin; and return; set -lx __jit_atuin 1; test -f \"$cache_dir/atuin.fish\"; or x_runtimes_build; source \"$cache_dir/atuin.fish\"; _atuin_bind_up \$argv; end" >> "$tmp_frontend"
    end
    
    # 4. FZF
    if set -l bin_path (command -s fzf)
        set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"\$X_RUNTIMES_FRONTEND\""
        begin
            fzf --fish > "$cache_dir/fzf.fish.$fish_pid"
            and command mv "$cache_dir/fzf.fish.$fish_pid" "$cache_dir/fzf.fish"
        end &
        set -a bg_pids $last_pid
        
        echo "function fzf-file-widget; set -q __jit_fzf; and return; set -lx __jit_fzf 1; test -f \"$cache_dir/fzf.fish\"; or x_runtimes_build; source \"$cache_dir/fzf.fish\"; fzf-file-widget \$argv; end" >> "$tmp_frontend"
        echo "function fzf-cd-widget; set -q __jit_fzf; and return; set -lx __jit_fzf 1; test -f \"$cache_dir/fzf.fish\"; or x_runtimes_build; source \"$cache_dir/fzf.fish\"; fzf-cd-widget \$argv; end" >> "$tmp_frontend"
    end
    
    # =========================================================
    # EXAMPLE: HOW TO ADD A NEW RUNTIME (e.g., MISE)
    # =========================================================
    # if set -l bin_path (command -s mise)
    #     set invalidation_checks "$invalidation_checks; or test \"$bin_path\" -nt \"\$X_RUNTIMES_FRONTEND\""
    #     mise activate fish > "$cache_dir/mise.fish.$fish_pid"
    #     and command mv "$cache_dir/mise.fish.$fish_pid" "$cache_dir/mise.fish" &
    #     set -a bg_pids $last_pid
    #     
    #     # Generate JIT-wrapper (e.g., hooking on PWD change)
    #     echo "function __mise_env --on-variable PWD; set -q __jit_mise; and return; set -lx __jit_mise 1; test -f \"$cache_dir/mise.fish\"; or x_runtimes_build; source \"$cache_dir/mise.fish\"; __mise_env \$argv; end" >> "$tmp_frontend"
    # end
    # =========================================================
    
    # ---------------------------------------------------------
    # WAIT FOR BACKGROUND CACHE GENERATION
    # ---------------------------------------------------------
    if set -q bg_pids[1]
        wait $bg_pids
    end
    
    # ---------------------------------------------------------
    # INJECT INVALIDATION BLOCK INTO FRONTEND
    # ---------------------------------------------------------
    set invalidation_checks (string replace -r "^; or " "" "$invalidation_checks")
    
    if test -n "$invalidation_checks"
        set -l final_frontend "$cache_dir/final_frontend.fish.$fish_pid"
        echo "if $invalidation_checks" > "$final_frontend"
        echo "    x_runtimes_build &" >> "$final_frontend"
        echo "end" >> "$final_frontend"
        cat "$tmp_frontend" >> "$final_frontend"
        command mv "$final_frontend" "$frontend_file"
        command rm "$tmp_frontend"
    else
        command mv "$tmp_frontend" "$frontend_file"
    end
end
