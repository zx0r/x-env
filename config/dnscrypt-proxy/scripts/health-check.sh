#!/bin/bash

# Production DNS Health Check Script
# Validates socket liveness, upstream resolution, local cache, and blocklist sinkholing.

set -e

# --- Configuration ---
DNS_PORT=53
DNS_IP="127.0.0.1"

# Dynamic Path Resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/dnscrypt-proxy.toml"

CACHE_DIR="/opt/homebrew/var/cache/dnscrypt-proxy"
BLOCKLIST_DOMAIN="doubleclick.net"

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
PID=$(pgrep -x dnscrypt-proxy | head -n1 || true)
if [ -n "$PID" ]; then
	RUN_USER=$(ps -o user= -p "$PID" 2>/dev/null || echo "unknown")
	echo -e "${GREEN}RUNNING (PID: $PID, User: $RUN_USER)${NC}"
elif brew services list 2>/dev/null | grep -q "dnscrypt-proxy[[:space:]]*started"; then
	echo -e "${GREEN}RUNNING (Brew Service)${NC}"
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

# 4. Cache Efficiency Test
echo -ne "4. Cache Efficiency Test: "
dig @$DNS_IP -p $DNS_PORT apple.com >/dev/null 2>&1
QUERY_TIME_CACHE=$(dig @$DNS_IP -p $DNS_PORT apple.com +stats | grep "Query time" | awk '{print $4}' || echo "")
if [[ "$QUERY_TIME_CACHE" =~ ^[0-9]+$ ]] && [ "$QUERY_TIME_CACHE" -le 2 ]; then
	echo -e "${GREEN}PASS (${QUERY_TIME_CACHE} ms)${NC}"
else
	echo -e "${YELLOW}SLOW/MISS (${QUERY_TIME_CACHE:-N/A} ms)${NC}"
fi

# 5. Anonymization (Relay Check)
echo -ne "5. Anonymization (Anonymized DNS): "
RELAY_CHECK=$(dig @$DNS_IP -p $DNS_PORT TXT debug.dnscrypt-proxy +short 2>/dev/null || true)
if [[ "$RELAY_CHECK" == *"via"* ]]; then
	echo -e "${GREEN}ACTIVE (Relayed)${NC}"
else
	echo -e "${YELLOW}DIRECT (Standard Encrypted Upstream)${NC}"
fi

# 6. Secure ECS (CDN Geolocation)
echo -ne "6. Secure ECS Check (Relay IP): "
ECS_IP=$(dig @$DNS_IP -p $DNS_PORT TXT o-o.myaddr.l.google.com +short 2>/dev/null | tr -d '"' || true)
if [ -n "$ECS_IP" ]; then
	echo -e "${GREEN}ACTIVE ($ECS_IP)${NC}"
else
	echo -e "${YELLOW}NOT RETURNED (Normal for non-ECS upstreams)${NC}"
fi

# 7. Local Blocklist Check
echo -ne "7. Local Blocklist (Domain Sinkhole): "
BLOCK_RESULT=$(dig @$DNS_IP -p $DNS_PORT $BLOCKLIST_DOMAIN +short 2>/dev/null || true)
if [ -z "$BLOCK_RESULT" ]; then
	echo -e "${GREEN}ACTIVE (Blocked)${NC}"
else
	echo -e "${RED}FAILED (Domain resolved: $BLOCK_RESULT)${NC}"
fi

# 8. Decoupled Path Audit
echo -ne "8. Configuration Decoupling: "
if [ -d "$CACHE_DIR" ] && [ ! -f "$PROJECT_ROOT/public-resolvers.md" ] && [ ! -f "$PROJECT_ROOT/quad9-resolvers.md" ]; then
	echo -e "${GREEN}CLEAN (Runtime state decoupled)${NC}"
else
	echo -e "${YELLOW}DIRTY (Runtime files detected in repository)${NC}"
fi

echo -e "${BLUE}==============================================${NC}"
