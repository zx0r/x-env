# ---
# schema: "mdd-node-v1"
# id: "conf.d/01-variables.fish"
# title: "Foundation Environment Variables"
# layer: "Foundation (00-09)"
# responsibility: "Exports global environment settings, locales, telemetry opt-outs, and tool variables"
# dependencies: ["conf.d/00-xdg.fish"]
# backlinks: ["config.fish", "conf.d/10-runtimes.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-09-09"
# last_commit: "pending"
# tags: ["variables", "environment", "telemetry", "locale", "x-workspace"]
# ---

# ━━━━━━━━━━━━━━ System Compatibility & Behavior ━━━━━━━━━━━━━━
# Prevents creation of AppleDouble "._" files when copying/archiving (tar, cp)
set -gx COPYFILE_DISABLE 1
# Silences bash deprecation warnings when invoking subshells on macOS
set -gx BASH_SILENCE_DEPRECATION_WARNING 1

# ━━━━━━━━━━━━━━ iTerm2 Terminal Integration ━━━━━━━━━━━━━━
set -gx ITERM_SHELL_INTEGRATION YES
set -gx ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX 1

# ━━━━━━━━━━━━━━ macOS System Preferences (Architectural Reference) ━━━━━━━━━━━━━━
# NOTE: macOS preference keys (NSGlobalDomain, etc.) are user defaults settings,
# NOT environment variables. Exporting them in the shell environment has zero effect
# and pollutes the environment namespace.
#
# To apply these preferences natively on macOS, execute the following commands once:
#   defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
#   defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
#   defaults write NSGlobalDomain AppleShowAllExtensions -bool true
#   defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
#   defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
#   defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
#   defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
#   defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
#   defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
#   defaults write NSGlobalDomain AppleFontSmoothing -int 2
#   defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
#   defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
#   defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
#   defaults write com.apple.Preview PVImageDPI -int 300
#   defaults write com.apple.Preview PVImageCompression -int 0
#   defaults write com.apple.TextEdit RichText -int 0

# ━━━━━━━━━━━━━━ Security & Privacy Enhancements ━━━━━━━━━━━━━━
set -gx NPM_CONFIG_AUDIT true
set -gx DOCKER_CONTENT_TRUST 1

# ━━━━━━━━━━━━━━ Telemetry & Analytics Opt-out ━━━━━━━━━━━━━━
# Universal Signal
set -gx DO_NOT_TRACK 1

# Language & Runtime CLI Telemetry Disables
set -gx DOTNET_CLI_TELEMETRY_OPTOUT 1
set -gx POWERSHELL_TELEMETRY_OPTOUT 1
set -gx DENO_NO_ANALYTICS 1
set -gx HINT_TELEMETRY off

# Cloud Provider SDK Telemetry Disables
set -gx AZURE_CORE_COLLECT_TELEMETRY 0
set -gx CLOUDSDK_CORE_DISABLE_USAGE_REPORTING true
set -gx SAM_CLI_TELEMETRY 0

# DevOps & Infrastructure Tooling Telemetry Disables
set -gx CHECKPOINT_DISABLE 1 # Disables HashiCorp (Terraform, Packer, Consul, Vagrant) telemetry/checkpoint services
set -gx HOMEBREW_NO_ANALYTICS 1 # Disables Homebrew analytics tracking

# JS/TS Web Development Framework & Tools Telemetry Disables
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

# Version Control Telemetry Disables
set -gx GH_NO_TELEMETRY 1

# Monitoring & Error Reporting CLI Telemetry Disables
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

# ━━━━━━━━━━━━━━ Language & Locale Settings ━━━━━━━━━━━━━━
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LC_TIME en_US.UTF-8
set -gx LC_CTYPE en_US.UTF-8
set -gx LC_NUMERIC en_US.UTF-8
set -gx PYTHONIOENCODING UTF-8
set -gx LC_MESSAGES en_US.UTF-8
set -gx LC_MONETARY en_US.UTF-8

# ━━━━━━━━━━━━━━ Terminal Settings ━━━━━━━━━━━━━━
set -gx TERMINAL kitty
set -gx CLICOLOR 1
set -gx COLORTERM truecolor
# set -gx FORCE_COLOR 3
# set -gx CLICOLOR_FORCE 1

# NOTE: Custom MANPATH/INFOPATH overrides are removed as they override the system
# default lookup paths and break standard manual lookups (e.g. `man ls`).
# macOS automatically resolves Homebrew's man pages when MANPATH is left empty.

# ━━━━━━━━━━━━━━ Pager & Text Display Settings ━━━━━━━━━━━━━━
set -gx LESS "-F -g -i -M -R -S -w -z-4"
set -gx PAGER "less -R"
set -gx MANROFFOPT "-P -c"

# ━━━━━━━━━━━━━━ Color Configurations ━━━━━━━━━━━━━━
set -gx FDFIND_COLORS "sp=33:ex=31:fi=32:di=34:ln=35:or=31"
set -gx GREP_COLORS 'mt=1;33:sl=:cx=:fn=35:ln=32:bn=32:se=36'
# NOTE: EZA_COLORS is not set here to avoid double-definition/redundancy.
# It is dynamically loaded from ~/.config/eza_colors inside config.fish.

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

# ━━━━━━━━━━━━━━ Tmux Configuration ━━━━━━━━━━━━━━
set -gx TMUX_TMPDIR $XDG_RUNTIME_DIR
set -gx TMUX_CONFIG_HOME "$XDG_CONFIG_HOME/tmux"
set -gx TMUX_PLUGIN_MANAGER_PATH "$XDG_DATA_HOME/tmux/plugins"

# ━━━━━━━━━━━━━━ Development Tools Configuration ━━━━━━━━━━━━━━
set -gx GHQ_ROOT $HOME/x/dev

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

# Git Tracing (Disabled for optimal performance)
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

# ━━━━━━━━━━━━━━ Language-Specific Paths ━━━━━━━━━━━━━━
set -gx RUSTUP_HOME "$HOME/.local/share/rustup"
set -gx CARGO_HOME "$HOME/.local/share/.cargo"

# ━━━━━━━━━━━━━━ Editor & Config Files ━━━━━━━━━━━━━━
set -gx XINITRC "$HOME/.xinitrc"
set -gx NVIMRC "$XDG_CONFIG_HOME/nvim/init.lua"

# ━━━━━━━━━━━━━━ Tools & Utilities ━━━━━━━━━━━━━━
set -gx BOB_HOME "$XDG_DATA_HOME/bob/nvim-bin"
set -gx BOB_CONFIG "$XDG_CONFIG_HOME/bob/config.json"
set -gx RIPGREP_CONFIG_PATH "$XDG_CONFIG_HOME/ripgrep/ripgreprc"

# Starship Logs & Configs
set -gx STARSHIP_CONFIG "$XDG_CONFIG_HOME/starship/starship.toml"
set -gx STARSHIP_LOG error

# ━━━━━━━━━━━━━━ Security & Network ━━━━━━━━━━━━━━
set -gx WGETRC "$XDG_CONFIG_HOME/wget/wgetrc"
set -gx CURL_HOME "$XDG_CONFIG_HOME/curl"
set -gx CURL_BIN /opt/homebrew/opt/curl/bin
set -gx CURL_CA_BUNDLE "/opt/homebrew/etc/ca-certificates/cert.pem"

# ━━━━━━━━━━━━━━ OpenSSL Prefixes ━━━━━━━━━━━━━━
set -gx OPENSSL_PREFIX /opt/homebrew/opt/openssl@3
set -gx OPENSSL_INCDIR "$OPENSSL_PREFIX/include"
set -gx OPENSSL_LIBDIR "$OPENSSL_PREFIX/lib"
set -gx OPENSSL_DIR "$OPENSSL_PREFIX"
set -gx LDFLAGS "-L$OPENSSL_LIBDIR"
set -gx CPPFLAGS "-I$OPENSSL_INCDIR"
set -gx PKG_CONFIG_PATH "$OPENSSL_LIBDIR/pkgconfig"

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
