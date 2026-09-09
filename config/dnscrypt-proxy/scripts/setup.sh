#!/bin/bash

# DEV VErsion!!!! Not tested
# ==============================================================================
#  _____ _      _____ _____ _____   ______ _   _  _____
# |  ___| |    |_   _|_   _|  ___|  |  _  \ \ | |/  ___|
# | |__ | |      | |   | | | |__    | | | |  \| |\ `--.
# |  __|| |      | |   | | |  __|   | | | | . ` | `--. \
# | |___| |____ _| |_  | | | |___   | |/ /| |\  |/\__/ /
# \____/\_____/\___/  \_/ \____/   |___/ \_| \_/\____/
#
#  ADAPTIVE STEALTH DNS INFRASTRUCTURE (v2026.05)
# ==============================================================================
# Description:
# This script automates the deployment of a PhD-level DNSCrypt-proxy stack.
# It ensures maximum speed through QUIC/HTTP3, anonymity via Relays/ODoH,
# and DPI resilience via local deterministic filtering.
#
# Logic:
# 1. Validates dependencies (Homebrew, dnscrypt-proxy).
# 2. Clones/Updates the configuration in ~/.config/dnscrypt-proxy.
# 3. Creates professional system directory hierarchy for cache/logs.
# 4. Sets up macOS LaunchDaemons for autonomous daily updates.
# 5. Hardens system network interfaces against DNS leaks.
# 6. Executes a full health-check suite.
# ==============================================================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Starting Elite DNS Infrastructure Setup...${NC}"

 #sudo ln -s "$CONF_DIR/dnscrypt-proxy.toml" /opt/homebrew/etc/
 #sudo ln -s "$CONF_DIR/rules" /opt/homebrew/etc/rules

# 1. Dependency Check
echo "--- Step 1: Checking Dependencies ---"
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found. Please install it first.${NC}"
    exit 1
fi

if ! brew list dnscrypt-proxy &> /dev/null; then
    echo "Installing dnscrypt-proxy via Homebrew..."
    brew install dnscrypt-proxy
fi

# 2. Directory Structure Setup
echo "--- Step 2: Setting up Directory Hierarchy ---"
CONF_DIR="$HOME/.config/dnscrypt-proxy"
CACHE_DIR="/opt/homebrew/var/cache/dnscrypt-proxy"
LOG_DIR="/opt/homebrew/var/log/dnscrypt-proxy"

mkdir -p "$CONF_DIR"
sudo mkdir -p "$CACHE_DIR" "$LOG_DIR"
sudo chown -R root:admin "$CACHE_DIR" "$LOG_DIR"
sudo chmod -R 775 "$CACHE_DIR" "$LOG_DIR"

# 3. Configuration Deployment (Assuming local file context or GitHub fallback)
echo "--- Step 3: Deploying Configuration ---"
# If running in the repo, just use current files. If not, user should clone it.
if [ ! -f "dnscrypt-proxy.toml" ]; then
    echo -e "${RED}Error: Configuration files not found in current directory.${NC}"
    echo "Please run this script from inside your configuration repository."
    exit 1
fi

cp *.toml *.txt *.md *.sh *.plist "$CONF_DIR/"
chmod +x "$CONF_DIR/"*.sh

# 4. System Symlink (Homebrew integration)
echo "--- Step 4: Linking Configuration to Homebrew ---"
sudo rm -f /opt/homebrew/etc/dnscrypt-proxy.toml
sudo ln -s "$CONF_DIR/dnscrypt-proxy.toml" /opt/homebrew/etc/dnscrypt-proxy.toml

# 5. Autonomous Maintenance Setup (Launchd)
echo "--- Step 5: Configuring Autonomous Maintenance ---"
PLIST="com.x0r.dnscrypt.maintenance.plist"
sudo cp "$CONF_DIR/$PLIST" "/Library/LaunchDaemons/$PLIST"
sudo chown root:wheel "/Library/LaunchDaemons/$PLIST"
sudo launchctl unload -w "/Library/LaunchDaemons/$PLIST" 2>/dev/null || true
sudo launchctl load -w "/Library/LaunchDaemons/$PLIST"

# 6. OS Hardening (Anti-Leak)
echo "--- Step 6: Hardening macOS Network Interfaces ---"
SERVICES=$(networksetup -listallnetworkservices | grep -v '*')
while IFS= read -r service; do
    echo "Securing DNS for: $service"
    sudo networksetup -setdnsservers "$service" 127.0.0.2 2>/dev/null || true
    # Note: If using port 5353, additional OS routing or a local forwarder might be needed for system-wide use.
done <<< "$SERVICES"

# 7. Final Validation
echo "--- Step 7: Executing Health-Check Suite ---"
sudo brew services restart dnscrypt-proxy
sleep 5
cd "$CONF_DIR"
./scripts/health-check.sh

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}   ELITE DNS INFRASTRUCTURE DEPLOYED SUCCESSFULLY ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo "Your config is now safe in $CONF_DIR"
echo "Daily updates scheduled at 03:00 AM."
