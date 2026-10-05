# ---
# schema: "mdd-node-v1"
# id: "conf.d/20-abbr.fish"
# title: "Command Abbreviations Registry"
# layer: "Commands (20-29)"
# responsibility: "Registers user command abbreviations for quick workspace and tool navigation"
# dependencies: ["functions/trash.fish", "functions/storage_audit.fish", "functions/storage_clean.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-04"
# last_commit: "pending"
# tags: ["abbreviations", "shortcuts", "productivity", "x-workspace", "trash", "storage"]
# ---

# Defensive check: Abbreviations are only relevant for interactive shell usage
status is-interactive; or return

# --------------------------------------------------------------------- #

# JIT Loader: Defers 120+ abbreviation registrations (~2ms parsing) to the first prompt
function __lazy_register_abbrs --on-event fish_prompt
# System maintenance architecture:
# - Boundary: each adapter owns one macOS subsystem: net, dns, ui.
# - Naming grammar: <subsystem><operation>.
# - Operations:
#   reset = restart/reinitialize subsystem state
#   clean = remove cache/state owned by subsystem
#   check = inspect state without mutation
# - Commands requiring sudo must stay explicit and narrow.
# - Prefer native macOS tools; avoid mixing unrelated subsystems.

# Network/system controls:
# - Purpose: quick recovery and inspection for common macOS networking/UI issues.
# - Context: Wi-Fi may use DHCP DNS by default; dnscrypton forces DNS through local dnscrypt-proxy at 127.0.0.1:53.
# - Safety: commands with sudo mutate system network state; check before reset/clean when unsure.

# network: interface control
abbr -a netcheck 'ifconfig (networksetup -listallhardwareports | awk "/Wi-Fi|AirPort/{getline; print \$2}")'
abbr -a netreset 'set iface (networksetup -listallhardwareports | awk "/Wi-Fi|AirPort/{getline; print \$2}"); sudo ifconfig $iface down; sudo ifconfig $iface up'
abbr -a netactive 'route get default | awk "/interface:/{print \$2}"'
abbr -a netservices 'networksetup -listallnetworkservices'

# dns: resolver cache and DNSCrypt switching
abbr -a dnsget 'networksetup -getdnsservers Wi-Fi'
abbr -a dnscrypton 'sudo networksetup -setdnsservers Wi-Fi 127.0.0.1; sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
abbr -a dnsauto 'sudo networksetup -setdnsservers Wi-Fi Empty; sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
abbr -a dnscheck 'networksetup -getdnsservers Wi-Fi; scutil --dns | rg "nameserver|resolver"; dig example.com @127.0.0.1'
abbr -a dnsclean 'sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
abbr -a dnsservices 'for svc in (networksetup -listallnetworkservices | string match -v "\\*"); echo "[$svc]"; networksetup -getdnsservers "$svc"; end'

# ui: restart user interface services without rebooting macOS
abbr -a uireset 'killall Dock; killall Finder; killall SystemUIServer'

# --------------------------------------------------------------------- #

# Tool maintenance architecture:
# - Boundary: each tool owns its lifecycle and storage: brew, mise, bun, npm, pip.
# - Abbreviations are thin adapters over native tool commands.
# - Naming grammar: <tool><operation>.
# - Operations:
#   get   = print canonical storage/cache path
#   check = inspect state without mutation
#   up    = update/upgrade managed artifacts
#   clean = remove tool-owned safe/obsolete artifacts
#   du    = inspect disk usage of canonical storage/cache path
#   doc   = run diagnostics
#   dry   = preview cleanup without mutation
# - Low-level adapters must not cross tool boundaries.
# - Cross-tool workflows belong only in the pkg* composition layer.
# - Prefer native cleanup commands; use rm only for known cache roots.

# brew: macOS packages, casks, native system tools
abbr -a brewget 'brew --cache'
abbr -a brewcheck 'brew update; brew outdated --greedy-latest'
abbr -a brewup 'brew update; brew upgrade --greedy-latest'
abbr -a brewclean 'brew autoremove; brew cleanup --prune=all'
abbr -a brewdry 'brew cleanup --prune=all --dry-run'
abbr -a brewdoc 'brew doctor'
abbr -a brewmissing 'brew missing'
abbr -a brewmaintain 'brew_maintain'

# dua-cli,mole,dut,ncdu
abbr -a brewdu 'dua (brew --cache)'

# Homebrew Automated Maintenance Engine (update -> greedy upgrade -> missing audit -> doctor -> autoremove -> cleanup)
# Background scheduling is managed by launchd (~/Library/LaunchAgents/com.user.brew-maintenance.plist)
abbr -a brewcron 'brew_maintain'

# mise: runtime/tool version manager
abbr -a miseget 'set -q MISE_DATA_DIR; and echo "$MISE_DATA_DIR"; or echo "$HOME/.local/share/mise"'
abbr -a misecheck 'mise ls'
abbr -a miseup 'mise upgrade'
abbr -a miseclean 'mise prune'
abbr -a misedu 'dua (set -q MISE_DATA_DIR; and echo "$MISE_DATA_DIR"; or echo "$HOME/.local/share/mise")'

# bun: JS runtime/package-manager cache
abbr -a bunget 'set -q XDG_CACHE_HOME; and echo "$XDG_CACHE_HOME/.bun"; or echo "$HOME/.cache/.bun"'
abbr -a buncheck 'bun --version; which bun; mise where bun'
abbr -a bundu 'dua (set -q XDG_CACHE_HOME; and echo "$XDG_CACHE_HOME/.bun"; or echo "$HOME/.cache/.bun")'
abbr -a bunclean 'bun pm cache rm'

# npm: legacy/global npm cache
abbr -a npmget 'npm config get cache'
abbr -a npmdu 'dua (npm config get cache)'
abbr -a npmclean 'npm cache verify'

# pip: Python package cache
abbr -a pipget 'pip cache dir'
abbr -a pipdu 'dua (pip cache dir)'
abbr -a pipcheck 'pip cache info'
abbr -a pipclean 'pip cache purge'

# composition: explicit cross-tool workflows
abbr -a pkgcheck 'brew update; brew outdated; mise ls; bun --version; pip cache info'
abbr -a pkgclean 'brew autoremove; brew cleanup --prune=all; mise prune; npm cache verify; pip cache purge'

# --------------------------------------------------------------------- #
# Disk space tooling contract:
abbr -a doprune "docker system prune -a --volumes -f"

# disk: essential macOS disk space toolkit
abbr -a diskfree 'df -h / /System/Volumes/Data'
abbr -a disktop 'dust -d 2 <path>'

# --------------------------------------------------------------------- #
# Workspace Artifact Sweepers (kondo, npkill)
# - Boundary: scoped to developer workspaces, targeting build artifacts (target/, node_modules/).
# - Safety: default to interactive TUI; npkill strictly excludes hidden dirs to protect app caches.

if type -q kondo
    abbr -a kondodry 'kondo --dry-run'
    abbr -a kondox 'kondo ~/x'
    abbr -a kondodev 'kondo $X_DEV'
end

if type -q npkill
    abbr -a npkilldry 'npkill --dry-run'
    abbr -a npkillx 'npkill -d ~/x --sort size --exclude-hidden-directories'
    abbr -a npkilldev 'npkill -d $X_DEV --sort size --exclude-hidden-directories'
end

# mole: safety-first macOS cleanup workflows
abbr -a mohome 'mo analyze $HOME'
abbr -a modisk 'mo analyze'
abbr -a movolumes 'mo analyze /Volumes'
abbr -a mocheck 'mo clean --dry-run; mo installer --dry-run; mo purge --dry-run'
abbr -a mocleandry 'mo clean --dry-run --debug'
abbr -a moclean 'mo clean'
abbr -a mopurgedry 'mo purge --dry-run'
abbr -a mopurge 'mo purge'
abbr -a moinstallerdry 'mo installer --dry-run'
abbr -a moinstaller 'mo installer'
abbr -a mohist 'mo history'
abbr -a mostatus 'mo status'

# composition: workstation storage lifecycle (audit, clean & safety governor)
abbr -a saudit storage_audit
abbr -a sclean storage_clean
abbr -a tlist 'trash -l'
abbr -a tempty 'trash -e'

# --------------------------------------------------------------------- #

# 3. Core Editor & Terminal Shorthands
abbr -a c clear
abbr -a n nvim

# 4. File Management Utilities (Protected Deletion via trash Governor)
abbr -a ln 'ln -sfv'
abbr -a cp 'cp -priv'
abbr -a mv 'mv -iv'
abbr -a rm trash
abbr -a mkdir 'mkdir -pv'
abbr -a mkdir-app 'mkdir -pv {src,public,tests}/{api,components,lib,utils}'

# 5. Fast Directory Navigation
abbr -a - 'cd -'
abbr -a .. 'cd ..'
abbr -a ... 'cd ../../'
abbr -a .... 'cd ../../../'
abbr -a ..... 'cd ../../../../'

abbr -a cds "cd $XDG_DATA_HOME"
abbr -a cfg "cd $XDG_CONFIG_HOME"
abbr -a cdb "cd $XDG_BIN_HOME"

abbr -a cdt "cd $XDG_CONFIG_HOME/tmux"
abbr -a cdf "cd $XDG_CONFIG_HOME/fish"
abbr -a cdn "cd $XDG_CONFIG_HOME/nvim"

# 6. Editing & Sourcing Configs
abbr -a ea "nvim $XDG_CONFIG_HOME/fish/conf.d/20-abbr.fish"
abbr -a et "nvim $XDG_CONFIG_HOME/tmux/tmux.conf"
abbr -a ef "nvim $XDG_CONFIG_HOME/fish/config.fish"

abbr -a sa "source $XDG_CONFIG_HOME/fish/conf.d/20-abbr.fish"
abbr -a sf "source $XDG_CONFIG_HOME/fish/config.fish"
abbr -a st "tmux source-file $XDG_CONFIG_HOME/tmux/tmux.conf"

# 7. File Permissions Shortcuts
abbr -a 000 'chmod -R 000' # No permissions for owner, group, or others
abbr -a 500 'chmod -R 500' # r-x------   Avoid Changing
abbr -a 600 'chmod -R 600' # rw-------   Read and write for owner only
abbr -a 644 'chmod -R 644' # rw-r--r--   Read/write for owner, read for group/others
abbr -a 660 'chmod -R 660' # rw-rw----   Read/write for owner and group
abbr -a 700 'chmod -R 700' # rwx------   Full access for owner only
abbr -a 755 'chmod -R 755' # rwxr-xr-x   Full access for owner, read/execute for others
abbr -a 777 'chmod -R 777' # rwxrwxrwx   Full access for everyone

abbr -a chmod- 'chmod -x'
abbr -a chmod+ 'chmod ug+x'

# 8. Dynamic eza / ls Setup (Avoids duplicate 'l' definition clashing)
if type -q eza
    abbr -a l "clear; and ll"
    abbr -a l. "eza -a | grep -E '^\\.'"
    abbr -a ls "eza -al --color=always --group-directories-first"
    abbr -a la "eza -a --color=always --group-directories-first"
    abbr -a ll "eza -abghilmu --icons=auto --color=always --group-directories-first"
    abbr -a lt "eza -aT --icons=auto --color=always --group-directories-first -snew"
    abbr -a lx "eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale --color=always --group-directories-first --icons=auto"
    abbr -a t "eza --tree --color=always --icons=auto"
    abbr -a t2 "eza --tree --level=2 --color=always --group-directories-first --icons=auto -snew"
    abbr -a t3 "eza --tree --level=3 --color=always --group-directories-first --icons=auto -snew"
    abbr -a t4 "eza --tree --level=4 --color=always --group-directories-first --icons=auto -snew"
else
    abbr -a l "ls -lah"
    abbr -a la "ls -A"
    abbr -a ll "ls -lAFh"
    abbr -a lb "ls -lhSA"
    abbr -a lm "ls -tA -1"
end

# 9. Git Version Control Abbreviations
abbr -a g git
abbr -a gs "git status"
abbr -a ga "git add"
abbr -a gc "git commit"
abbr -a gp "git push"
abbr -a gl "git log --oneline -n 20"
abbr -a gd "git diff"
abbr -a gco "git checkout"
abbr -a gb "git branch"
abbr -a lg lazygit
abbr -a dot "git --git-dir=$HOME/.git_bare_repo --work-tree=$HOME"

# 10. Network & Port Inspection
abbr -a myip "curl ifconfig.me"
abbr -a ports "sudo lsof -iTCP -sTCP:LISTEN -P -n"

# 11. Tmux Session Orchestration
abbr -a ta "tmux attach -t"
abbr -a td "tmux attach -td"
abbr -a tn "tmux new-session -sd"
abbr -a ts "tmux switch-client -t"
abbr -a tl 'tmux list-sessions'
abbr -a tkw 'tmux kill-window -t'
abbr -a tks 'tmux kill-server'
abbr -a tkss 'tmux kill-session -t'
abbr -a tkall 'tmux list-sessions -F "#{session_name}" | xargs -I{} tmux kill-session -t {}'

# TMX (Ultimate Tmux Session Manager) abbreviations
abbr -a tx tmx
abbr -a txn 'tmx new'
abbr -a txd 'tmx daily'
abbr -a txs 'tmx switch'
abbr -a txk 'tmx kill'
abbr -a txl 'tmx ls'

# 12. Performance & Resource Auditing
abbr -a mem "vm_stat | awk '{print \$1, \$2}'"
abbr -a cpu "top -o cpu -stats pid,cpu,command"

# 13. Disk Usage & Performance Fallbacks (dust / ncdu support)
if type -q dust
    abbr -a du dust
    abbr -a dud "dust -d 1"
    abbr -a dush "dust -s"
else
    abbr -a du "du -ht"
    abbr -a dum "du --max-depth=1"
    abbr -a dus "du --summarize"
    abbr -a dud "du -d 1 -h"
    abbr -a dush "du -sh *"
end

if type -q ncdu
    abbr -a nd ncdu
end

# 14. Robust File Download Protocols (HTTP/3 and speed stats)
abbr -a cget "curl --proto '=https' --tlsv1.2 --http3 --compressed -fL#SO --write-out '\n⚡ %{speed_download} B/s • ⏱ %{time_total}s • 📦 %{size_download} bytes\n'"
abbr -a cpipe "curl --proto '=https' --tlsv1.2 --http3 --compressed -fsSL"
abbr -a curls 'curl -fOsSL --output-dir <some/dir/> {url}'
abbr -a curld 'curl -fsSL --output-dir <some/dir/filename> {url}'

abbr -a wget 'wget -O {url}'
abbr -a wget_output 'wget -qO- {url}'
abbr -a wgetd 'wget -P <some/dir/filename> {url}'

# 15. Zoxide Navigation (Wrapped for safety to prevent breaking standard cd)
if type -q zoxide
    abbr -a cd z
    abbr -a zz zi
end

# 16. Kitty Terminal Helpers
abbr -a kr "kitty @ load-config"
abbr -a ssh-kitty "kitty +kitten ssh user@host"

if type -q docker
    abbr -a d docker
    abbr -a dim 'docker images'
    abbr -a dp 'docker ps'
    abbr -a dpa 'docker ps -a'
    abbr -a dpq 'docker ps -q'
    abbr -a drmc 'docker rm -v (docker ps -qaf status=exited)'
    abbr -a drmca 'docker rm -fv (docker ps -qa)'
    abbr -a drmi 'docker rmi (docker images -qf dangling=true)'
    abbr -a drmig 'docker rmi (docker images -qf reference=)'
end

if type -q docker-compose
    abbr -a dc docker-compose
    abbr -a dcl 'docker-compose logs'
end

if type -q kubectl
    abbr -a kb kubectl
    abbr -a kbg 'kubectl get'
    abbr -a kbd 'kubectl describe'
    abbr -a kbl 'kubectl logs'
end

# System Monitoring
abbr -a memhog 'ps -eo pid,ppid,cmd,%mem --sort=-%mem | head' # Processes consuming most memory
abbr -a cpuhog 'ps -eo pid,ppid,cmd,%cpu --sort=-%cpu | head' # Processes consuming most CPU
abbr -a psgrep --set-cursor 'ps aux | grep -v grep | grep -i -e VSZ -e %' # Custom ps grep (% = cursor)

# Copy / pasting (macOS)
abbr -a cpwd 'pwd | pbcopy' # Copy current path
abbr -a pa pbpaste # Paste clipboard contents

# SSH and file transfer commands
abbr -a ssh256 "set -gx TERM xterm-256color command ssh"
abbr -a mosh "set -gx TERM xterm-256color command mosh"
abbr -a sshrev 'ssh -CqTnN -R 0.0.0.0:8443:192.168.1.2:443 user@202.115.8.1' # # Reverse Proxy: Forward port (8443) from external host (202.115.8.1) to internal host (192.168.1.2:443)
abbr -a sshfwd 'ssh -CqTnN -L 0.0.0.0:8443:192.168.1.2:443 user@192.168.1.3' # # Forward Proxy: Forward local port (8443) through 192.168.1.3 to internal host (192.168.1.2:443)
abbr -a sshsocks 'ssh -CqTnN -D localhost:1080 user@202.115.8.1' # # SOCKS5 Proxy: Forward SOCKS5 proxy requests from local port (1080) through remote host
abbr -a sshfs 'sshfs name@server:/path/to/folder /path/to/mount/point' # Mount a remote filesystem over SSH
abbr -a sshwrt 'ssh root@openwrt.lan' # Login to remote host as user
abbr -a sshport 'ssh -p {port} user@host' # Login to host specifying port
abbr -a sshcopy 'ssh-copy-id user@host' # Copy SSH key to remote host to avoid password prompts
abbr -a scp_push 'scp {fn} user@host:path' # Copy file to remote host
abbr -a scp_pull 'scp user@host:path dest' # Copy file from remote host
abbr -a scp_port 'scp -P {port} ...' # Copy file to remote host specifying port

abbr -a valid_json 'python -m json.tool settings.json > /dev/null && echo "✅ Valid JSON"'


# ━━━━━━━━━━━━━━ Meta-Workspace (~/x) Navigation ━━━━━━━━━━━━━━
abbr -a xx 'cd $X_ROOT'
abbr -a xa 'cd $X_AGENTS'
abbr -a xb 'cd $X_BRAIN'
abbr -a xc 'cd $X_CONFIG'
abbr -a xd 'cd $X_DEV'
abbr -a xn 'cd $X_DEV/nda'
abbr -a xo 'cd $X_DEV/own'
abbr -a xt 'x_toggle'

# Self-destruct hook to ensure it only runs once
functions -e __lazy_register_abbrs
end
