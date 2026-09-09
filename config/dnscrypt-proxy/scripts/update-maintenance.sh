#!/usr/bin/env bash

# Elite DNS Maintenance Script
# Automates blocklist updates and directory health checks.
# https://github.com/dyne/dnscrypt-proxy/blob/master/contrib/generate-domains-blacklist.py

# Dynamic Path Resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/rules"

CACHE_DIR="/opt/homebrew/var/cache/dnscrypt-proxy"
GEN_SCRIPT="$PROJECT_ROOT/dns-update/generate-domains-blacklist_.py" # Adjust if path differs

echo "--- DNS Maintenance Started: $(date) ---"

# 1. Update Blocklist
if [ -f "$GEN_SCRIPT" ]; then
    echo "Running blocklist generator..."
    python3 "$GEN_SCRIPT" -c "$CONFIG_DIR/domains-blocklist.conf" -o "$CACHE_DIR/domains-blocklist.txt"
else
    echo "Warning: Blocklist generator script not found at $GEN_SCRIPT"
    # Fallback to direct download if generator is missing
    echo "Downloading fresh HaGezi Multi PRO (FULL) as fallback..."
    curl -sSL "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro-onlydomains.txt" -o "$CACHE_DIR/domains-blocklist.txt"
fi

# 2. Fix Permissions
sudo chown root:admin "$CACHE_DIR/domains-blocklist.txt"
sudo chmod 644 "$CACHE_DIR/domains-blocklist.txt"

# 3. Reload Service
sudo brew services restart dnscrypt-proxy

echo "--- Maintenance Complete ---"
