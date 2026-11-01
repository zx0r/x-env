# ---
# schema: "mdd-node-v1"
# id: "functions/__x_init_vars.fish"
# title: "Interactive Variables, Toolchains & Presentation Subsystem Initializer"
# layer: "Functions / Presentation"
# responsibility: "Deferred initialization of interactive environment variables, 24-bit TrueColor palette, Vi cursor shapes, telemetry opt-outs, toolchain flags, and GNU/Eza color maps"
# dependencies: []
# backlinks: ["conf.d/init.fish"]
# created_at: "2026-10-15"
# updated_at: "2026-10-18"
# tags: ["vars", "palette", "presentation", "jit", "zero-fork-sla", "principal"]
# ---

function __x_init_vars --description "Initialize interactive variables, colors, and presentation environment"
    # ━━━━━━━━━━━━━━ User Directories ━━━━━━━━━━━━━━
    set -q XDG_DESKTOP_DIR; or set -gx XDG_DESKTOP_DIR "$HOME/Desktop"
    set -q XDG_DOCUMENTS_DIR; or set -gx XDG_DOCUMENTS_DIR "$HOME/Documents"
    set -q XDG_DOWNLOADS_DIR; or set -gx XDG_DOWNLOADS_DIR "$HOME/Downloads"
    set -q XDG_PICTURES_DIR; or set -gx XDG_PICTURES_DIR "$HOME/Pictures"
    set -q XDG_VIDEOS_DIR; or set -gx XDG_VIDEOS_DIR "$HOME/Movies"
    set -q XDG_MUSIC_DIR; or set -gx XDG_MUSIC_DIR "$HOME/Music"
    set -q XDG_PUBLICSHARE_DIR; or set -gx XDG_PUBLICSHARE_DIR "$HOME/Public"

    # ━━━━━━━━━━━━━━ Meta-Workspace Taxonomy (~/x) ━━━━━━━━━━━━━━
    set -q X_ROOT; or set -gx X_ROOT "$HOME/x"
    set -q X_AGENTS; or set -gx X_AGENTS "$X_ROOT/agents"
    set -q X_BRAIN; or set -gx X_BRAIN "$X_ROOT/brain"
    set -q X_CONFIG; or set -gx X_CONFIG "$X_ROOT/config"
    set -q X_DEV; or set -gx X_DEV "$X_ROOT/dev"

    # ━━━━━━━━━━━━━━ Core POSIX & System Directives ━━━━━━━━━━━━━━
    set -gx COPYFILE_DISABLE 1
    set -gx BASH_SILENCE_DEPRECATION_WARNING 1
    set -gx NPM_CONFIG_AUDIT true
    set -gx DOCKER_CONTENT_TRUST 1
    set -gx LANG en_US.UTF-8
    set -gx LC_ALL en_US.UTF-8
    set -gx PYTHONIOENCODING UTF-8

    set -gx NVIM_APPNAME nvim/zx0r
    set -gx EDITOR nvim
    set -gx VISUAL nvim
    set -gx SUDO_EDITOR nvim

    # ━━━━━━━━━━━━━━ Git Ecosystem & Security Directives ━━━━━━━━━━━━━━
    set -gx GIT_CONFIG_GLOBAL "$HOME/.config/git/config"
    set -gx GIT_EDITOR nvim
    set -gx GIT_PAGER delta
    set -gx GIT_ASKPASS ""
    set -gx GIT_SSL_NO_VERIFY 0
    set -gx GIT_DISCOVERY_ACROSS_FILESYSTEM 0
    set -gx GIT_TERMINAL_PROMPT 1

    # ━━━━━━━━━━━━━━ Toolchain Homes & Secrets ━━━━━━━━━━━━━━
    set -gx GHQ_ROOT "$HOME/x/dev"
    set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
    set -gx CARGO_HOME "$HOME/.local/share/.cargo"
    set -gx BOB_HOME "$XDG_DATA_HOME/bob/nvim-bin"
    set -gx BOB_CONFIG "$XDG_CONFIG_HOME/bob/config.json"
    set -gx TRASHDIR "$HOME/.Trash"
    set -gx SSH_HOME "$HOME/.ssh"
    set -gx GNUPGHOME "$HOME/.gnupg"
    set -gx PASSWORD_STORE_DIR "$XDG_DATA_HOME/password-store"
    set -gx SOPS_AGE_KEY_FILE "$XDG_CONFIG_HOME/sops/age/keys.txt"

    # ━━━━━━━━━━━━━━ OpenSSL Toolchain ━━━━━━━━━━━━━━
    set -gx OPENSSL_PREFIX /opt/homebrew/opt/openssl@3
    set -gx OPENSSL_INCDIR "$OPENSSL_PREFIX/include"
    set -gx OPENSSL_LIBDIR "$OPENSSL_PREFIX/lib"
    set -gx OPENSSL_DIR "$OPENSSL_PREFIX"
    set -gx LDFLAGS "-L$OPENSSL_LIBDIR"
    set -gx CPPFLAGS "-I$OPENSSL_INCDIR"
    set -gx PKG_CONFIG_PATH "$OPENSSL_LIBDIR/pkgconfig"

    # ━━━━━━━━━━━━━━ Homebrew Environment Governors ━━━━━━━━━━━━━━
    set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
    set -gx HOMEBREW_REPOSITORY /opt/homebrew
    set -gx HOMEBREW_BREWFILE "$XDG_CONFIG_HOME/brewfile/Brewfile"
    set -gx HOMEBREW_NO_ANALYTICS 1
    set -gx HOMEBREW_NO_AUTO_UPDATE 1
    set -gx HOMEBREW_AUTO_UPDATE_SECS 604800
    set -gx HOMEBREW_API_AUTO_UPDATE_SECS 86400
    set -gx HOMEBREW_INSTALL_FROM_API 1
    set -gx HOMEBREW_NO_ENV_HINTS 1
    set -gx HOMEBREW_NO_INSECURE_REDIRECT 1
    set -gx HOMEBREW_ARTIFACT_DOMAIN_NO_FALLBACK 1
    set -gx HOMEBREW_FORCE_BREWED_CA_CERTIFICATES 1
    set -gx HOMEBREW_CLEANUP_MAX_AGE_DAYS 30
    set -gx HOMEBREW_CLEANUP_PERIODIC_FULL_DAYS 30
    set -gx HOMEBREW_CURL_RETRIES 3
    set -gx HOMEBREW_FORCE_VENDOR_RUBY 1
    set -gx CURL_HOME "$XDG_CONFIG_HOME/curl"
    set -gx CURL_BIN "/opt/homebrew/opt/curl/bin"
    set -gx CURL_CA_BUNDLE "/opt/homebrew/etc/ca-certificates/cert.pem"
    set -gx SSL_CERT_FILE "/opt/homebrew/etc/ca-certificates/cert.pem"
    set -gx HOMEBREW_FORCE_BREWED_CURL 1

    # ━━━━━━━━━━━━━━ Login UX & Color Maps ━━━━━━━━━━━━━━
    if test -f "$XDG_CONFIG_HOME/ls_colors"
        read -z LS_COLORS <"$XDG_CONFIG_HOME/ls_colors"
        set -gx LS_COLORS (string trim $LS_COLORS)
    end

    if test -f "$XDG_CONFIG_HOME/eza_colors"
        read -z EZA_COLORS <"$XDG_CONFIG_HOME/eza_colors"
        set -gx EZA_COLORS (string trim $EZA_COLORS)
    end
    set -gx EZA_ICONS_AUTO 1

    # ━━━━━━━━━━━━━━ iTerm2 / Terminal Integrations ━━━━━━━━━━━━━━
    set -gx ITERM_SHELL_INTEGRATION YES
    set -gx ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX 1

    # ━━━━━━━━━━━━━━ Telemetry & Analytics Opt-out ━━━━━━━━━━━━━━
    set -gx DO_NOT_TRACK 1
    set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
    set -gx POWERSHELL_TELEMETRY_OPTOUT 1
    set -gx DENO_NO_ANALYTICS 1
    set -gx HINT_TELEMETRY off
    set -gx AZURE_CORE_COLLECT_TELEMETRY 0
    set -gx CLOUDSDK_CORE_DISABLE_USAGE_REPORTING true
    set -gx SAM_CLI_TELEMETRY 0
    set -gx CHECKPOINT_DISABLE 1
    set -gx NEXT_TELEMETRY_DISABLED 1
    set -gx NUXT_TELEMETRY_DISABLED 1
    set -gx GATSBY_TELEMETRY_DISABLED 1
    set -gx ASTRO_TELEMETRY_DISABLED 1
    set -gx VERCEL_TELEMETRY_DISABLED 1
    set -gx TURBO_TELEMETRY_DISABLED 1
    set -gx SUPABASE_TELEMETRY_OPTOUT 1
    set -gx STRIPE_CLI_TELEMETRY_OPTOUT 1
    set -gx STORYBOOK_DISABLE_TELEMETRY 1
    set -gx PRISMA_CLI_TELEMETRY_OPTOUT 1
    set -gx EXPO_NO_TELEMETRY 1
    set -gx YARN_ENABLE_TELEMETRY 0
    set -gx APOLLO_TELEMETRY_DISABLED 1
    set -gx NG_CLI_ANALYTICS false
    set -gx HASURA_CLI_TELEMETRY_OPTOUT true
    set -gx STRAPI_TELEMETRY_DISABLED true
    set -gx GH_NO_TELEMETRY 1
    set -gx SENTRY_TELEMETRY_DISABLED 1
    set -gx SENTRY_CLI_NO_UPDATE_CHECK 1

    # ━━━━━━━━━━━━━━ Disable History Storage (Privacy) ━━━━━━━━━━━━━━
    set -gx NODE_REPL_HISTORY ""
    set -gx PSQL_HISTORY /dev/null
    set -gx LESSHISTFILE /dev/null
    set -gx MYSQL_HISTFILE /dev/null
    set -gx SQLITE_HISTORY /dev/null
    set -gx PYTHONHISTFILE /dev/null
    set -gx REDISCLI_HISTFILE /dev/null

    # ━━━━━━━━━━━━━━ Terminal Settings ━━━━━━━━━━━━━━
    set -gx TERMINAL kitty
    set -gx CLICOLOR 1
    set -gx COLORTERM truecolor

    if test "$TERMINAL" = kitty -o -n "$KITTY_WINDOW_ID"
        set -gx SNACKS_KITTY 1
    end

    set -gx NVIM_NOTTYFAST 1

    # ━━━━━━━━━━━━━━ Pager & Text Display Settings ━━━━━━━━━━━━━━
    set -gx LESS "-F -g -i -M -R -S -w -z-4"
    set -gx PAGER "less -R"
    set -gx MANROFFOPT "-P -c"

    # ━━━━━━━━━━━━━━ Color Configurations ━━━━━━━━━━━━━━
    set -gx FDFIND_COLORS "sp=33:ex=31:fi=32:di=34:ln=35:or=31"
    set -gx GREP_COLORS 'mt=1;33:sl=:cx=:fn=35:ln=32:bn=32:se=36'

    # ━━━━━━━━━━━━━━ VSCode & Chromium Flags ━━━━━━━━━━━━━━
    set -gx VSCODE_CLI 1
    set -gx VSCODE_DEV 0
    set -gx VSCODE_DEBUG 0
    set -gx VSCODE_PORTABLE 1
    set -gx VSCODE_CRASH_REPORTER_START_OPTIONS '{"companyName":"","productName":"","uploadToServer":false}'
    set -gx CHROMIUM_FLAGS "--disable-background-networking --disable-breakpad --disable-crash-reporter --disable-default-apps --disable-domain-reliability --disable-sync --disable-telemetry --no-default-browser-check --no-first-run --no-pings"

    set -gx ELECTRON_ENABLE_LOGGING 0
    set -gx ELECTRON_NO_ATTACH_CONSOLE 1
    set -gx ELECTRON_ENABLE_STACK_DUMPING 0

    # ━━━━━━━━━━━━━━ Tig & Starship Configuration ━━━━━━━━━━━━━━
    set -gx TIGRC_USER "$XDG_CONFIG_HOME/tig/tigrc"
    set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship/starship.toml"
    set -gx STARSHIP_LOG error

    # ━━━━━━━━━━━━━━ Less Termcap Colors ━━━━━━━━━━━━━━
    set -gx LESS_TERMCAP_mb \e"[1;32m"
    set -gx LESS_TERMCAP_mh \e"[2m"
    set -gx LESS_TERMCAP_mr \e"[7m"
    set -gx LESS_TERMCAP_md \e"[1;36m"
    set -gx LESS_TERMCAP_ZW ""
    set -gx LESS_TERMCAP_us \e"[4;1;37m"
    set -gx LESS_TERMCAP_me \e"[0m"
    set -gx LESS_TERMCAP_ue \e"[0m"
    set -gx LESS_TERMCAP_ZO ""
    set -gx LESS_TERMCAP_ZN ""
    set -gx LESS_TERMCAP_se \e"[0m"
    set -gx LESS_TERMCAP_ZV ""
    set -gx LESS_TERMCAP_so \e"[1;33m"

    # ━━━━━━━━━━━━━━ Interactive Tool Options ━━━━━━━━━━━━━━
    set -gx MANPAGER "bat -l man -p"
    set -gx BAT_CONFIG_DIR "$XDG_CONFIG_HOME/bat"
    set -gx BAT_CONFIG_PATH "$XDG_CONFIG_HOME/bat/bat.conf"

    set -gx FZF_CD_COMMAND "fd -t d"
    set -gx FZF_OPEN_COMMAND "fd -H -t f"
    set -gx FZF_FIND_FILE_COMMAND "fd -t f"
    set -gx FZF_CD_WITH_HIDDEN_COMMAND "fd -H -t d"

    # ━━━━━━━━━━━━━━ Git Ergonomics ━━━━━━━━━━━━━━
    set -gx GIT_PS1_SHOWDIRTYSTATE 1
    set -gx GIT_PS1_SHOWSTASHSTATE 1
    set -gx GIT_PS1_SHOWUNTRACKEDFILES 1
    set -gx GIT_MERGE_AUTOEDIT no
    set -gx GIT_COMPLETION_CHECKOUT_NO_GUESS 1

    # ━━━━━━━━━━━━━━ Interactive Tooling & Runtimes ━━━━━━━━━━━━━━
    set -gx LG_CONFIG_DIR "$XDG_CONFIG_HOME/lazygit"
    set -gx RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/ripgreprc"
    set -gx PUPPETEER_EXECUTABLE_PATH "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    set -gx WGETRC "$XDG_CONFIG_HOME/wget/wgetrc"

    # ━━━━━━━━━━━━━━ Tmux Session Configuration ━━━━━━━━━━━━━━
    set -gx TMUX_TMPDIR $XDG_RUNTIME_DIR
    set -gx TMUX_CONFIG_HOME "$XDG_CONFIG_HOME/tmux"
    set -gx TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins"

    # ━━━━━━━━━━━━━━ Task Management ━━━━━━━━━━━━━━
    set -gx TASKRC "$XDG_CONFIG_HOME/task/taskrc"
    set -gx TASKDATA "$XDG_CONFIG_HOME/task"
    set -gx TASKOPENRC "$XDG_CONFIG_HOME/taskopen/taskopenrc"
    set -gx TIMEWARRIORDB "$XDG_DATA_HOME/timewarrior/tw.db"

    # ━━━━━━━━━━━━━━ Presentation & Terminal Optimization ━━━━━━━━━━━━━━
    set -g fish_handle_reflow 0
    set -g fish_prompt_pwd_dir_length 0
    set -g fish_handle_term24bit 0
    set -gx fish_command_timer_enabled 1
    set -g fish_trace_commands 0
    set -g fish_history_max_length 50000
    set -g fish_autosuggestion_enabled 1
    set -g __fish_git_prompt_show_informative_status 1
    set -g fish_complete_timeout 0.1

    # ━━━━━━━━━━━━━━ Environment X Color Palette & Cursor ━━━━━━━━━━━━━━
    set -g fish_term256 1

    # Command Line Syntax Highlighting
    set -g fish_color_normal FFFFFF
    set -g fish_color_command 00FF00
    set -g fish_color_keyword F40091
    set -g fish_color_param 00FFFF
    set -g fish_color_option 00FFFF
    set -g fish_color_quote FFFF00
    set -g fish_color_comment 646B84
    set -g fish_color_operator F40091
    set -g fish_color_escape FF8C00
    set -g fish_color_redirection 0A84FF

    # Command Line State & Highlighting
    set -g fish_color_autosuggestion 4A5168
    set -g fish_color_match 00FF00
    set -g fish_color_search_match brwhite --background=1F2333
    set -g fish_color_selection 00FFFF --background=1F2333
    set -g fish_color_cancel FF0000
    set -g fish_color_end CD00F7
    set -g fish_color_error FF0000

    # Path Highlighting Colors
    set -g fish_color_valid_path 00FF00 --underline
    set -g fish_color_valid_path_file 00FFFF
    set -g fish_color_valid_path_dir 0A84FF

    # Shell Prompt Customization
    set -g fish_color_user 00FF00
    set -g fish_color_host FFFFFF
    set -g fish_color_host_remote FFFF00
    set -g fish_color_status FF0000
    set -g fish_color_history_current --bold
    set -g fish_color_cwd 0A84FF
    set -g fish_color_cwd_root FF0000
    set -g fish_color_pwd_bg 000000
    set -g fish_color_pwd_dir_bg 000000

    # Autocompletion Pager Customization (fish_pager)
    set -g fish_pager_color_completion FFFFFF
    set -g fish_pager_color_prefix 00FFFF --bold --underline
    set -g fish_pager_color_progress 00FF00
    set -g fish_pager_color_description FFFF00
    set -g fish_pager_color_selected_background --background=1F2333
    set -g fish_pager_color_selected_prefix 00FFFF
    set -g fish_pager_color_selected_completion FFFFFF
    set -g fish_pager_color_selected_description FFFF00
    set -g fish_pager_color_secondary_background 181B28
    set -g fish_pager_color_secondary_prefix 00FFFF
    set -g fish_pager_color_secondary_completion FFFFFF
    set -g fish_pager_color_secondary_description 646B84

    # Terminal Cursor Engine (Vi Mode Shapes)
    set -g fish_vi_force_cursor 1
    set -g fish_cursor_default underscore blink
    set -g fish_cursor_insert underscore blink
    set -g fish_cursor_visual block
    set -g fish_cursor_replace_one underscore

    # Self-evict to prevent memory leak and guarantee 0 recurring overhead
    functions -e __x_init_vars
end
