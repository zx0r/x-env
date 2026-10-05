# ---
# schema: "mdd-node-v1"
# id: "conf.d/01-variables.fish"
# title: "Foundation Environment Variables"
# layer: "Foundation (00-09)"
# responsibility: "Exports global environment settings, locales, telemetry opt-outs, and tool variables"
# dependencies: ["conf.d/00-xdg.fish"]
# backlinks: ["config.fish", "conf.d/02-brew.fish", "conf.d/10-runtimes.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-04"
# last_commit: "2e7eeb6"
# tags: ["variables", "environment", "telemetry", "locale", "x-workspace", "lazy-eval"]
# ---

# ==============================================================================
# SECTION 1: NON-INTERACTIVE / CORE ENVIRONMENT
# These variables are required by subshells, cron jobs, and editor integrations
# ==============================================================================

# ━━━━━━━━━━━━━━ System Compatibility & Behavior ━━━━━━━━━━━━━━
# Prevents creation of AppleDouble "._" files when copying/archiving (tar, cp)
set -gx COPYFILE_DISABLE 1
# Silences bash deprecation warnings when invoking subshells on macOS
set -gx BASH_SILENCE_DEPRECATION_WARNING 1

# ━━━━━━━━━━━━━━ Security & Privacy Enhancements ━━━━━━━━━━━━━━
set -gx NPM_CONFIG_AUDIT true
set -gx DOCKER_CONTENT_TRUST 1

# ━━━━━━━━━━━━━━ Language & Locale Settings ━━━━━━━━━━━━━━
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LC_TIME en_US.UTF-8
set -gx LC_CTYPE en_US.UTF-8
set -gx LC_NUMERIC en_US.UTF-8
set -gx PYTHONIOENCODING UTF-8
set -gx LC_MESSAGES en_US.UTF-8
set -gx LC_MONETARY en_US.UTF-8

# ━━━━━━━━━━━━━━ Editor & Config Files ━━━━━━━━━━━━━━
set -gx XINITRC "$HOME/.xinitrc"
set -gx NVIMRC "$XDG_CONFIG_HOME/nvim/init.lua"
# Static editor resolution (eliminates dynamic PATH walks during boot)
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx GIT_EDITOR nvim
set -gx SUDO_EDITOR nvim

# ━━━━━━━━━━━━━━ Development Tools Configuration ━━━━━━━━━━━━━━
set -gx GHQ_ROOT $HOME/x/dev
set -gx LG_CONFIG_DIR "$XDG_CONFIG_HOME/lazygit"
set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
set -gx CARGO_HOME "$HOME/.local/share/.cargo"
set -gx BOB_HOME "$XDG_DATA_HOME/bob/nvim-bin"
set -gx BOB_CONFIG "$XDG_CONFIG_HOME/bob/config.json"
set -gx RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# ━━━━━━━━━━━━━━ Tmux Configuration ━━━━━━━━━━━━━━
set -gx TMUX_TMPDIR $XDG_RUNTIME_DIR
set -gx TMUX_CONFIG_HOME "$XDG_CONFIG_HOME/tmux"
set -gx TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins"

# ━━━━━━━━━━━━━━ Task Management ━━━━━━━━━━━━━━
set -gx TASKRC "$XDG_CONFIG_HOME/task/taskrc"
set -gx TASKDATA "$XDG_CONFIG_HOME/task"
set -gx TASKOPENRC "$XDG_CONFIG_HOME/taskopen/taskopenrc"
set -gx TIMEWARRIORDB "$XDG_DATA_HOME/timewarrior/tw.db"

# ━━━━━━━━━━━━━━ Safe rm ━━━━━━━━━━━━━━
set -gx TRASHDIR "$HOME/.Trash"

# ━━━━━━━━━━━━━━ SSH & GPG Defaults ━━━━━━━━━━━━━━
set -gx SSH_HOME "$HOME/.ssh"
set -gx GNUPGHOME "$HOME/.gnupg"
set -gx PASSWORD_STORE_DIR "$XDG_DATA_HOME/password-store"

# ━━━━━━━━━━━━━━ Security & Network ━━━━━━━━━━━━━━
set -gx WGETRC "$XDG_CONFIG_HOME/wget/wgetrc"
# Note: Homebrew-specific network and TLS hardening (Brewed Curl, CA Certificates)
# is isolated in conf.d/02-brew.fish to guarantee correct prefix resolution order.

# ━━━━━━━━━━━━━━ OpenSSL Prefixes ━━━━━━━━━━━━━━
set -gx OPENSSL_PREFIX /opt/homebrew/opt/openssl@3
set -gx OPENSSL_INCDIR "$OPENSSL_PREFIX/include"
set -gx OPENSSL_LIBDIR "$OPENSSL_PREFIX/lib"
set -gx OPENSSL_DIR "$OPENSSL_PREFIX"
set -gx LDFLAGS "-L$OPENSSL_LIBDIR"
set -gx CPPFLAGS "-I$OPENSSL_INCDIR"
set -gx PKG_CONFIG_PATH "$OPENSSL_LIBDIR/pkgconfig"


# ==============================================================================
# SECTION 2: INTERACTIVE-ONLY ENVIRONMENT
# The following ~150 lines are entirely bypassed during non-interactive scripts
# ==============================================================================
status is-interactive; or return

# ------------------------------------------------------------------------------
# Performance Optimization: Lazy JIT Variable Initialization
# Telemetry opt-outs, tool flags (BAT, FZF), and pager colors are deferred to
# the first fish_prompt event. This eliminates ~400 µs of sequential AST
# evaluations on the cold interactive boot path with zero process forks.
# ------------------------------------------------------------------------------
function __x_init_interactive_vars --on-event fish_prompt
    functions -e __x_init_interactive_vars
    if set -q __X_INTERACTIVE_VARS_SET; return; end
# ━━━━━━━━━━━━━━ iTerm2 Terminal Integration ━━━━━━━━━━━━━━
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
# HOMEBREW_NO_ANALYTICS is exported unconditionally in conf.d/02-brew.fish (covers subshells & launchd)
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

# NOTE [TERMINAL DISCOVERY HARDENING & CHECKHEALTH FIX]:
# SNACKS_KITTY=1 resolves two critical issues in Neovim (snacks.nvim / image.nvim):
# 1. Fixes `:checkhealth snacks` error ("your terminal does not support the kitty graphics protocol")
#    inside tmux, where $TERM defaults to 'tmux-256color', causing snacks to fail terminal detection
#    and completely disable inline images and doc rendering.
# 2. Eliminates dynamic ANSI escape queries (\e[>q) on startup inside tmux/nested PTYs,
#    preventing TermResponse escape sequence leakage into stdin that typed garbage characters
#    (e.g. `tty(0.49.1)`) directly into active buffers due to extended-keys collisions.
# Guarantees deterministic, zero-overhead Kitty Graphics Protocol capability resolution.
if test "$TERMINAL" = "kitty" -o -n "$KITTY_WINDOW_ID"
    set -gx SNACKS_KITTY 1
end

# Disable blocking 100ms DSR background terminal queries in Neovim 0.12+ (E1568),
# preventing startup latency stalls and TermResponse escape sequence leakage into stdin.
set -gx NVIM_NOTTYFAST 1

# ━━━━━━━━━━━━━━ Pager & Text Display Settings ━━━━━━━━━━━━━━
set -gx LESS "-F -g -i -M -R -S -w -z-4"
set -gx PAGER "less -R"
set -gx MANROFFOPT "-P -c"

# ━━━━━━━━━━━━━━ Color Configurations ━━━━━━━━━━━━━━
set -gx FDFIND_COLORS "sp=33:ex=31:fi=32:di=34:ln=35:or=31"
set -gx GREP_COLORS 'mt=1;33:sl=:cx=:fn=35:ln=32:bn=32:se=36'

# ━━━━━━━━━━━━━━ VSCode & VSCodium Flags ━━━━━━━━━━━━━━
set -gx VSCODE_CLI 1
set -gx VSCODE_DEV 0
set -gx VSCODE_DEBUG 0
set -gx VSCODE_PORTABLE 1
set -gx VSCODE_CRASH_REPORTER_START_OPTIONS '{"companyName":"","productName":"","uploadToServer":false}'

# ━━━━━━━━━━━━━━ Chromium Flags ━━━━━━━━━━━━━━
set -gx CHROMIUM_FLAGS "--disable-background-networking --disable-breakpad --disable-crash-reporter --disable-default-apps --disable-domain-reliability --disable-sync --disable-telemetry --no-default-browser-check --no-first-run --no-pings"

# ━━━━━━━━━━━━━━ Electron Apps Behavior ━━━━━━━━━━━━━━
set -gx ELECTRON_ENABLE_LOGGING 0
set -gx ELECTRON_NO_ATTACH_CONSOLE 1
set -gx ELECTRON_ENABLE_STACK_DUMPING 0

# ━━━━━━━━━━━━━━ Git Security & Behavior ━━━━━━━━━━━━━━
set -gx GIT_ASKPASS ""
set -gx GIT_SSL_NO_VERIFY 0
set -gx GIT_DISCOVERY_ACROSS_FILESYSTEM 0
set -gx GIT_TERMINAL_PROMPT 1
set -gx GIT_PS1_SHOWDIRTYSTATE 1
set -gx GIT_PS1_SHOWSTASHSTATE 1
set -gx GIT_PS1_SHOWUNTRACKEDFILES 1
set -gx GIT_MERGE_AUTOEDIT no
set -gx GIT_COMPLETION_CHECKOUT_NO_GUESS 1
set -gx GIT_PAGER "less -FX"
set -gx GIT_TRACE 0
set -gx GIT_TRACE_CURL 0
set -gx GIT_TRACE_SETUP 0
set -gx GIT_TRACE_PACKET 0
set -gx GIT_TRACE_SHALLOW 0
set -gx GIT_TRACE_PACK_ACCESS 0
set -gx GIT_TRACE_PERFORMANCE 0
set -gx GIT_TRACE_CURL_NO_DATA 0

# ━━━━━━━━━━━━━━ Tig Interface ━━━━━━━━━━━━━━
set -gx TIGRC_USER "$XDG_CONFIG_HOME/tig/tigrc"

# Starship Logs & Configs
set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship/starship.toml"
set -gx STARSHIP_LOG error

# ━━━━━━━━━━━━━━ Less Termcap Colors (Man Pages) ━━━━━━━━━━━━━━
set -gx LESS_TERMCAP_mb \e"[1;32m" # bold green
set -gx LESS_TERMCAP_mh \e"[2m" # dim
set -gx LESS_TERMCAP_mr \e"[7m" # reverse
set -gx LESS_TERMCAP_md \e"[1;36m" # bold cyan
set -gx LESS_TERMCAP_ZW "" # no additional formatting
set -gx LESS_TERMCAP_us \e"[4;1;37m" # underline and bold white
set -gx LESS_TERMCAP_me \e"[0m" # end formatting
set -gx LESS_TERMCAP_ue \e"[0m" # end underline
set -gx LESS_TERMCAP_ZO "" # no additional formatting
set -gx LESS_TERMCAP_ZN "" # no additional formatting
set -gx LESS_TERMCAP_se \e"[0m" # end standout
set -gx LESS_TERMCAP_ZV "" # no additional formatting
set -gx LESS_TERMCAP_so \e"[1;33m" # bold yellow (transparent background)

# ━━━━━━━━━━━━━━ Bat, Fd, FZF, Editor (Interactive Tools) ━━━━━━━━━━━━━━
# Static exports avoid synchronous PATH traversal during boot
set -gx BAT_THEME Dracula
set -gx BAT_PAGER "less -rf"
set -gx MANPAGER "bat -l man -p"
set -gx BAT_CONFIG_DIR "$XDG_CONFIG_HOME/bat"
set -gx BAT_CONFIG_PATH "$XDG_CONFIG_HOME/bat/bat.conf"

set -gx FZF_CD_COMMAND "fd -t d"
set -gx FZF_OPEN_COMMAND "fd -H -t f"
set -gx FZF_FIND_FILE_COMMAND "fd -t f"
set -gx FZF_CD_WITH_HIDDEN_COMMAND "fd -H -t d"

    set -gx __X_INTERACTIVE_VARS_SET 1
end
