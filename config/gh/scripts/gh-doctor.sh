#!/usr/bin/env bash
# ==============================================================================
# GITHUB CLI PLATFORM DIAGNOSTIC & HEALTH ENGINE (gh-doctor)
# Platform : macOS Sequoia / Sonoma (Apple Silicon arm64 Darwin 25+)
# Standards: Zero-Trust Security | POSIX.1-2008
# Target   : /Users/x0r/.config/gh/scripts/gh-doctor.sh
# ==============================================================================

set -euo pipefail

# ANSI Color Palette
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

AUTO_FIX=false
if [[ "${1:-}" == "--fix" ]]; then
  AUTO_FIX=true
fi

pass() { echo -e "  [${GREEN}PASS${NC}] $1"; }
warn() { echo -e "  [${YELLOW}WARN${NC}] $1"; }
fail() { echo -e "  [${RED}FAIL${NC}] $1"; }
info() { echo -e "  [${CYAN}INFO${NC}] $1"; }

echo -e "\n${BOLD}==============================================================================${NC}"
echo -e "${BOLD}       ENTERPRISE GITHUB CLI ZERO-TRUST PLATFORM DIAGNOSTICS                  ${NC}"
echo -e "${BOLD}==============================================================================${NC}\n"

ERRORS=0
WARNINGS=0

# --- 1. CORE BINARY & RUNTIME ---
echo -e "${BOLD}1. Binary & Version Verification${NC}"
if command -v gh > /dev/null 2>&1; then
  GH_VER=$(gh --version | head -n 1)
  pass "GitHub CLI installed: ${GH_VER}"
else
  fail "gh binary not located in PATH"
  ((ERRORS++))
fi

# --- 2. AUTHENTICATION & KEYRING STATE ---
echo -e "\n${BOLD}2. Cryptographic Authentication & Keychain State${NC}"
if gh auth status > /dev/null 2>&1; then
  USER_INFO=$(gh api user --jq '"\(.login) (ID: \(.id))"')
  pass "Authenticated active account: ${USER_INFO}"

  # Check Keyring storage
  if gh auth status 2>&1 | grep -q "keyring"; then
    pass "Credential storage backed by macOS Keychain (secure storage)"
  else
    warn "Token not stored in macOS Keychain"
    ((WARNINGS++))
  fi
else
  fail "Authentication check failed. Run 'gh auth login'"
  ((ERRORS++))
fi

# --- 3. HARDWARE CRYPTOGRAPHIC KEY PROVENANCE ---
echo -e "\n${BOLD}3. Apple Secure Enclave & SSH Key Provenance${NC}"
PUBKEY_PATH="${HOME}/.ssh/zx0r_ecdsa-sha2-nistp256@github.pub"
if [[ -f "$PUBKEY_PATH" ]]; then
  pass "Local Secure Enclave public key located at ${PUBKEY_PATH}"
  LOCAL_KEY_PART=$(awk '{print $2}' "$PUBKEY_PATH")

  # Verify remote registration
  REMOTE_KEYS=$(gh api user/keys --jq '.[].key' 2> /dev/null || echo "")
  if echo "$REMOTE_KEYS" | grep -q "$LOCAL_KEY_PART"; then
    pass "Secure Enclave hardware key actively registered in GitHub account"
  else
    warn "Local public key not found in GitHub user keys list"
    ((WARNINGS++))
  fi
else
  warn "Hardware public key not found at expected path: ${PUBKEY_PATH}"
  ((WARNINGS++))
fi

# --- 4. PROTOCOL UNIFICATION ---
echo -e "\n${BOLD}4. Transport Protocol Alignment${NC}"
CFG_PROTO=$(gh config get git_protocol 2> /dev/null || echo "")
if [[ "$CFG_PROTO" == "ssh" ]]; then
  pass "config.yml protocol set to SSH (zero-trust cryptographic transport)"
else
  fail "config.yml protocol is '${CFG_PROTO}' (expected: ssh)"
  ((ERRORS++))
fi

# --- 5. RUNTIME PRIVACY & TELEMETRY GOVERNOR ---
echo -e "\n${BOLD}5. Telemetry & Privacy Governors${NC}"
TELEMETRY=$(gh config get telemetry 2> /dev/null || echo "")
if [[ "$TELEMETRY" == "disabled" ]]; then
  pass "Telemetry egress explicitly disabled (privacy & zero latency)"
else
  warn "Telemetry is '${TELEMETRY}' (recommended: disabled)"
  ((WARNINGS++))
fi

COLOR_LABELS=$(gh config get color_labels 2> /dev/null || echo "")
if [[ "$COLOR_LABELS" == "enabled" ]]; then
  pass "Truecolor RGB label rendering enabled"
else
  warn "Color labels not enabled"
  ((WARNINGS++))
fi

# --- 6. GITHUB API RATE LIMIT HEALTH ---
echo -e "\n${BOLD}6. GitHub API Quota & Rate Limit Health${NC}"
if gh ratelimit > /dev/null 2>&1; then
  RATELIMIT_STR=$(gh ratelimit)
  pass "${RATELIMIT_STR}"
else
  warn "Failed to query API rate limits"
  ((WARNINGS++))
fi

# --- 7. EXTENSION ECOSYSTEM ---
echo -e "\n${BOLD}7. Installed Extensions Matrix${NC}"
REQUIRED_EXTS=("dash" "poi" "markdown-preview" "webhook")
INSTALLED_EXTS=$(gh extension list | awk '{print $2}' || echo "")

for ext in "${REQUIRED_EXTS[@]}"; do
  if echo "$INSTALLED_EXTS" | grep -q "$ext"; then
    pass "Extension 'gh-${ext}' verified active"
  else
    warn "Extension 'gh-${ext}' is not installed (run scripts/install-extensions.sh)"
    ((WARNINGS++))
  fi
done

# --- 8. FILE PERMISSIONS & ZERO-TRUST SECURITY AUDIT ---
echo -e "\n${BOLD}8. Filesystem Permissions & Security Boundary${NC}"
GH_DIR="${HOME}/.config/gh"
CFG_FILE="${GH_DIR}/config.yml"
HOSTS_FILE="${GH_DIR}/hosts.yml"

check_perm() {
  local target="$1"
  local expected="$2"
  local actual
  actual=$(stat -f "%OLp" "$target" 2> /dev/null || echo "")
  if [[ "$actual" == "$expected" ]]; then
    pass "${target} permissions: ${actual} (compliant)"
  else
    if [[ "$AUTO_FIX" == true ]]; then
      chmod "$expected" "$target"
      pass "${target} permissions auto-fixed to ${expected}"
    else
      warn "${target} permissions: ${actual} (expected: ${expected})"
      ((WARNINGS++))
    fi
  fi
}

check_perm "$GH_DIR" "700"
check_perm "$CFG_FILE" "600"
if [[ -f "$HOSTS_FILE" ]]; then
  check_perm "$HOSTS_FILE" "600"
fi

# --- 9. TOOLCHAIN ECOSYSTEM INTEGRATION ---
echo -e "\n${BOLD}9. Toolchain Integration Check${NC}"
for tool in git fzf jq delta bat; do
  if command -v "$tool" > /dev/null 2>&1; then
    pass "Complementary tool '${tool}' available in PATH"
  else
    warn "Tool '${tool}' not found (recommended for full workflow capability)"
    ((WARNINGS++))
  fi
done

# --- SUMMARY ---
echo -e "\n${BOLD}==============================================================================${NC}"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}✓ ALL CHECKS PASSED. SYSTEM STATUS: BENCHMARK PLATFORM SPECIFICATION.${NC}"
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "${YELLOW}${BOLD}⚠ AUDIT PASSED WITH ${WARNINGS} WARNING(S). SYSTEM OPERATIONAL.${NC}"
else
  echo -e "${RED}${BOLD}✗ AUDIT FAILED WITH ${ERRORS} ERROR(S) AND ${WARNINGS} WARNING(S).${NC}"
fi
echo -e "${BOLD}==============================================================================${NC}\n"

exit $ERRORS
