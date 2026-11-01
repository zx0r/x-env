#!/usr/bin/env bash
# ==============================================================================
# GITHUB CLI EXTENSION LIFECYCLE MANAGER
# Platform : macOS Sequoia / Sonoma (Apple Silicon arm64 Darwin 25+)
# Target   : /Users/x0r/.config/gh/scripts/install-extensions.sh
# ==============================================================================

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

EXTENSIONS=(
  "dlvhdr/gh-dash"               # Interactive PR & Issue Terminal Cockpit / TUI
  "seachicken/gh-poi"            # Deterministic & safe cleanup of merged local branches
  "yusukebe/gh-markdown-preview" # Real-time GitHub Flavored Markdown previewer
  "cli/gh-webhook"               # Local webhook tunneling & replay engine
)

echo -e "\n${BOLD}==============================================================================${NC}"
echo -e "${BOLD}       PROVISIONING ENTERPRISE GITHUB CLI EXTENSIONS                          ${NC}"
echo -e "${BOLD}==============================================================================${NC}\n"

for repo in "${EXTENSIONS[@]}"; do
  ext_name="${repo##*/}"
  echo -e "${CYAN}→ Inspecting extension:${NC} ${BOLD}${ext_name}${NC} (${repo})"
  if gh extension list | grep -q "$ext_name"; then
    echo -e "  [${GREEN}FOUND${NC}] Extension already installed. Checking updates..."
    gh extension upgrade "$ext_name" 2> /dev/null || true
  else
    echo -e "  [${CYAN}INSTALLING${NC}] Installing ${repo}..."
    gh extension install "$repo"
    echo -e "  [${GREEN}INSTALLED${NC}] ${repo} provisioned successfully."
  fi
done

echo -e "\n${BOLD}Current Extension Manifest:${NC}"
gh extension list

echo -e "\n${GREEN}${BOLD}✓ All enterprise extensions are provisioned and synchronized.${NC}\n"
