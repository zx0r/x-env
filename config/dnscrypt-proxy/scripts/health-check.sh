#!/bin/bash

# Elite DNS Health Check Script (v2026.05)
# Designed for PhD-level adaptive DNS stacks in adversarial environments.

set -e

# --- Configuration ---
DNS_PORT=53
DNS_IP="127.0.0.2"

# Dynamic Path Resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/dnscrypt-proxy.toml"

CACHE_DIR="/opt/homebrew/var/cache/dnscrypt-proxy"
BLOCKLIST_DOMAIN=" ad.animehub.ac"

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== DNSCrypt-Proxy Professional Health Check ===${NC}"
date

# 1. Syntax Check
echo -ne "1. Configuration Syntax: "
if dnscrypt-proxy -check -config "$CONFIG_FILE" >/dev/null 2>&1; then
	echo -e "${GREEN}PASS${NC}"
else
	echo -e "${RED}FAIL (Check $CONFIG_FILE)${NC}"
fi

# 2. Service Status
echo -ne "2. System Service Status: "
if sudo brew services list | grep -q "dnscrypt-proxy[[:space:]]*started"; then
	echo -e "${GREEN}RUNNING (Root)${NC}"
elif brew services list | grep -q "dnscrypt-proxy[[:space:]]*started"; then
	echo -e "${GREEN}RUNNING (User)${NC}"
else
	echo -e "${RED}NOT STARTED${NC}"
fi

# 3. DNS Resolution & Latency
echo -ne "3. DNS Resolution (google.com): "
QUERY_TIME=$(dig @$DNS_IP -p $DNS_PORT google.com +stats | grep "Query time" | awk '{print $4}')
if [ ! -z "$QUERY_TIME" ]; then
	echo -e "${GREEN}OK (${QUERY_TIME} ms)${NC}"
else
	echo -e "${RED}FAILED${NC}"
fi

# 4. Cache Efficiency (Hyper-Caching)
echo -ne "4. Cache Efficiency Test: "
dig @$DNS_IP -p $DNS_PORT apple.com >/dev/null 2>&1
QUERY_TIME_CACHE=$(dig @$DNS_IP -p $DNS_PORT apple.com +stats | grep "Query time" | awk '{print $4}')
if [ "$QUERY_TIME_CACHE" -eq "0" ]; then
	echo -e "${GREEN}PASS (0 ms)${NC}"
else
	echo -e "${YELLOW}SLOW (${QUERY_TIME_CACHE} ms) - Cache not optimized?${NC}"
fi

# 5. Anonymization (Relay Check)
echo -ne "5. Anonymization (Anonymized DNS): "
# We check if the proxy reports relay usage in debug
RELAY_CHECK=$(dig @$DNS_IP -p $DNS_PORT TXT debug.dnscrypt-proxy +short)
if [[ $RELAY_CHECK == *"via"* ]] || [[ $(sudo tail -n 100 /opt/homebrew/var/log/dnscrypt-proxy.log 2>/dev/null | grep -i "routing everything via") ]]; then
	echo -e "${GREEN}ACTIVE (Stealth Mode)${NC}"
else
	echo -e "${YELLOW}UNKNOWN (Check logs for 'routing via')${NC}"
fi

# 6. Secure ECS (CDN Geolocation)
echo -ne "6. Secure ECS Check (Relay IP): "
ECS_IP=$(dig @$DNS_IP -p $DNS_PORT TXT o-o.myaddr.l.google.com +short | tr -d '"')
if [ ! -z "$ECS_IP" ]; then
	echo -e "${GREEN}ACTIVE ($ECS_IP)${NC}"
else
	echo -e "${RED}FAILED${NC}"
fi

# 7. DPI Evasion (Blocklist Check)
echo -ne "7. Local Blocklist (DPI-Evasion): "
BLOCK_RESULT=$(dig @$DNS_IP -p $DNS_PORT $BLOCKLIST_DOMAIN +short)
if [ -z "$BLOCK_RESULT" ]; then
	echo -e "${GREEN}ACTIVE (Blocked)${NC}"
else
	echo -e "${RED}FAILED (Domain resolved: $BLOCK_RESULT)${NC}"
fi

# 8. Decoupled Path Audit
echo -ne "8. Configuration Decoupling: "
if [ -f "$CACHE_DIR/public-resolvers.md" ] && [ ! -f "$PROJECT_ROOT/public-resolvers.md" ]; then
	echo -e "${GREEN}CLEAN (Git-ready)${NC}"
else
	echo -e "${YELLOW}DIRTY (Check file placement)${NC}"
fi

echo -e "${BLUE}==============================================${NC}"
