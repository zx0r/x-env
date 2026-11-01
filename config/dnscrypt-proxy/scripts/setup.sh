#!/usr/bin/env bash
# ==============================================================================
# dnscrypt-proxy macOS Deployment & Hardening Script
# Configures system symlinks, directories, network DNS, and launchd daemons.
# ==============================================================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting dnscrypt-proxy deployment...${NC}"

# Dynamic XDG & System Environment Variables
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo "/opt/homebrew")"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/../../config/dnscrypt-proxy" ]]; then
    SOT_CONF="$(cd "$SCRIPT_DIR/../../config/dnscrypt-proxy" && pwd)"
    SOT_BIN="$(cd "$SCRIPT_DIR/../../bin/dnscrypt-proxy" && pwd)"
else
    SOT_CONF="$(cd "$SCRIPT_DIR/.." && pwd)"
    SOT_BIN="$SCRIPT_DIR"
fi

CONF_DIR="$XDG_CONFIG_HOME/dnscrypt-proxy"
BIN_DIR="$XDG_BIN_HOME/dnscrypt-proxy"
CACHE_DIR="$BREW_PREFIX/var/cache/dnscrypt-proxy"
LOG_DIR="$BREW_PREFIX/var/log/dnscrypt-proxy"
PLIST_NAME="org.dnscrypt.dnsguard.plist"

# 1. Dependency Check
echo "--- Step 1: Checking Dependencies ---"
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${RED}Homebrew not found. Please install it first.${NC}"
    exit 1
fi

if ! brew list dnscrypt-proxy >/dev/null 2>&1; then
    echo "Installing dnscrypt-proxy via Homebrew..."
    brew install dnscrypt-proxy
fi

# 2. XDG Symlink Distribution
echo "--- Step 2: Provisioning XDG Symlinks ---"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_BIN_HOME"

if [[ "$SOT_CONF" != "$CONF_DIR" ]]; then
    ln -sfn "$SOT_CONF" "$CONF_DIR"
fi

if [[ "$SOT_BIN" != "$BIN_DIR" ]]; then
    ln -sfn "$SOT_BIN" "$BIN_DIR"
fi

chmod +x "$BIN_DIR"/* 2>/dev/null || true

# 3. System Directories & Blocklist Seed
echo "--- Step 3: Configuring System Directories ---"
sudo mkdir -p "$CACHE_DIR" "$LOG_DIR"
sudo chown -R root:admin "$CACHE_DIR" "$LOG_DIR"
sudo chmod -R 775 "$CACHE_DIR" "$LOG_DIR"

if [[ ! -f "$CACHE_DIR/domains-blocklist.txt" ]]; then
    echo "Downloading initial blocklist seed..."
    curl -sSL "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro-onlydomains.txt" \
        -o "$CACHE_DIR/domains-blocklist.txt"
    sudo chmod 644 "$CACHE_DIR/domains-blocklist.txt"
fi

# 4. Homebrew Integration Symlinks
echo "--- Step 4: Linking Configuration to Homebrew ---"
sudo ln -sfn "$CONF_DIR/dnscrypt-proxy.toml" "$BREW_PREFIX/etc/dnscrypt-proxy.toml"
sudo ln -sfn "$CONF_DIR/rules" "$BREW_PREFIX/etc/rules"

# 5. LaunchDaemon Setup
echo "--- Step 5: Configuring LaunchDaemon ---"
if [[ -f "$CONF_DIR/system/$PLIST_NAME" ]]; then
    sudo cp "$CONF_DIR/system/$PLIST_NAME" "/Library/LaunchDaemons/$PLIST_NAME"
    sudo chown root:wheel "/Library/LaunchDaemons/$PLIST_NAME"
    sudo chmod 644 "/Library/LaunchDaemons/$PLIST_NAME"
    sudo launchctl unload -w "/Library/LaunchDaemons/$PLIST_NAME" 2>/dev/null || true
    sudo launchctl load -w "/Library/LaunchDaemons/$PLIST_NAME"
fi

# 6. Network DNS Configuration
echo "--- Step 6: Configuring macOS Network DNS ---"
SERVICES=$(networksetup -listallnetworkservices 2>/dev/null | grep -v '*' || true)
while IFS= read -r service; do
    [[ -z "$service" ]] && continue
    echo "Setting DNS for: $service"
    sudo networksetup -setdnsservers "$service" 127.0.0.1 2>/dev/null || true
done <<< "$SERVICES"

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

# 7. Verification from XDG_BIN_HOME
echo "--- Step 7: Executing Verification ---"
sudo brew services restart dnscrypt-proxy
sleep 2

if [[ -x "$BIN_DIR/validate" ]]; then
    "$BIN_DIR/validate"
elif [[ -x "$BIN_DIR/health-check.sh" ]]; then
    "$BIN_DIR/health-check.sh"
fi

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}   dnscrypt-proxy setup complete and verified ${NC}"
echo -e "${GREEN}==============================================${NC}"
