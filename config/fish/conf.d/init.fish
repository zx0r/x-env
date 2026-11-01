# ---
# schema: "mdd-node-v1"
# id: "conf.d/init.fish"
# title: "Unified Zero-Fork Workstation Kernel (Single Entrypoint)"
# layer: "Foundation & Orchestration (00-99)"
# responsibility: "Single entrypoint for fish initialization: XDG layout, PATH, IPC socket, deferred JIT lazy bridge"
# dependencies: ["functions/__x_init_snapshot.fish", "functions/__x_init_vars.fish", "functions/__x_init_abbrs.fish", "functions/__x_init_fzf.fish", "functions/__x_init_eza.fish", "functions/fish_should_add_to_history.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-19"
# last_commit: "pending"
# tags: ["kernel", "entrypoint"]
# ---

set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME "$HOME/.config"
set -q XDG_CACHE_HOME; or set -gx XDG_CACHE_HOME "$HOME/.cache"
set -q XDG_DATA_HOME; or set -gx XDG_DATA_HOME "$HOME/.local/share"
set -q XDG_STATE_HOME; or set -gx XDG_STATE_HOME "$HOME/.local/state"
set -q XDG_BIN_HOME; or set -gx XDG_BIN_HOME "$HOME/.local/bin"

set -q XDG_RUNTIME_DIR; or begin
    if set -q TMPDIR; and test -n "$TMPDIR"
        set -gx XDG_RUNTIME_DIR (string trim -r -c / "$TMPDIR")
    else
        set -gx XDG_RUNTIME_DIR /tmp
    end
end

set -gx COPYFILE_DISABLE 1
set -gx BASH_SILENCE_DEPRECATION_WARNING 1
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx NVIM_APPNAME nvim/zx0r
set -gx EDITOR nvim
set -gx VISUAL nvim

test -d /System/Library; or return 0

set -gx HOMEBREW_PREFIX /opt/homebrew
test -d $HOMEBREW_PREFIX; or set -gx HOMEBREW_PREFIX /usr/local

set -l kitty_bin /Applications/kitty.app/Contents/MacOS
set -l ghostty_bin /Applications/Ghostty.app/Contents/MacOS

set -gx PATH \
    $XDG_BIN_HOME \
    $HOMEBREW_PREFIX/opt/curl/bin \
    $HOMEBREW_PREFIX/bin \
    $HOMEBREW_PREFIX/sbin \
    $XDG_DATA_HOME/bob/nvim-bin \
    $XDG_DATA_HOME/nvim/mason/bin \
    $HOME/.local/share/.cargo/bin \
    $HOME/.antigravity-ide/antigravity-ide/bin \
    $HOME/.gemini/antigravity-cli/bin \
    $HOME/.docker/bin \
    /usr/local/bin \
    /usr/bin /bin /usr/sbin /sbin \
    $kitty_bin \
    $ghostty_bin

status is-interactive; or return 0

if not set -q SSH_CLIENT; and not set -q SSH_CONNECTION; and not set -q SSH_TTY
    set -l _stable_link "$HOME/.ssh/ssh_auth_sock"
    set -l _secretive_sock "$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
    if test -S "$_stable_link"
        set -gx SSH_AUTH_SOCK "$_stable_link"
    else if test -S "$_secretive_sock"
        set -gx SSH_AUTH_SOCK "$_secretive_sock"
    end
end

set -g fish_greeting ""
set -g fish_key_bindings fish_vi_key_bindings
set -g fish_escape_delay_ms 10

function __init_interactive_lazy --on-event fish_prompt
    functions -e __init_interactive_lazy
    fish_user_key_bindings
    __x_init_snapshot
    __x_init_abbrs
    __x_init_vars
    __x_init_fzf
    __x_init_eza
end
