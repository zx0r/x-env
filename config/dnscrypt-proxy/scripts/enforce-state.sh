#!/usr/bin/env bash
# ==============================================================================
# dnscrypt-proxy State Enforcement & Resolver Guard
# Target   : /usr/local/bin/dnsguard-enforce.sh or scripts/enforce-state.sh
# Trigger  : LaunchDaemon WatchPaths on macOS network configuration changes
# ==============================================================================
set -euo pipefail

RESOLVER="127.0.0.1"
PORT="53"

# 1. LIVENESS CHECK: Verify dnscrypt-proxy is answering on localhost
if ! nc -z -w 1 "$RESOLVER" "$PORT" 2>/dev/null && ! dig @"$RESOLVER" -p "$PORT" localhost +time=1 +tries=1 >/dev/null 2>&1; then
    # Fallback: Try restarting dnscrypt-proxy daemon
    if command -v brew >/dev/null 2>&1; then
        /opt/homebrew/bin/brew services restart dnscrypt-proxy >/dev/null 2>&1 || true
        sleep 1
    fi
fi

# If resolver is still down, abort to avoid breaking network completely
if ! nc -z -w 1 "$RESOLVER" "$PORT" 2>/dev/null && ! dig @"$RESOLVER" -p "$PORT" localhost +time=1 +tries=1 >/dev/null 2>&1; then
    logger -t "dnsguard" "dnscrypt-proxy unreachable on 127.0.0.1:53. DNS enforcement bypassed."
    exit 1
fi

# 2. STATE ENFORCEMENT: Enforce 127.0.0.1 across all active network services
ACTIVE_SERVICES=$(networksetup -listallnetworkservices 2>/dev/null | grep -v '*' || true)

while IFS= read -r service; do
    [[ -z "$service" ]] && continue
    CURRENT_DNS=$(networksetup -getdnsservers "$service" 2>/dev/null || echo "")
    
    if [[ "$CURRENT_DNS" != "$RESOLVER" ]]; then
        networksetup -setdnsservers "$service" "$RESOLVER" 2>/dev/null || true
        logger -t "dnsguard" "DNS reset for '$service' -> $RESOLVER"
    fi
done <<< "$ACTIVE_SERVICES"
