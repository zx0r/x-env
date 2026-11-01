#!/usr/bin/env bash
# ============================================================================
# workstation_audit_oracle.sh — Multi-Domain Verification Harness
# x0r/nvim Zero-Overhead Reference Architecture
#
# 6-Gate Deterministic Scoring System (0–100 points)
# Domains: Neovim · Kitty · Tmux · SOLID · DevSecOps · LLMOps
#
# Usage:
#   ./scripts/workstation_audit_oracle.sh              # Full audit (local)
#   ./scripts/workstation_audit_oracle.sh --ci         # CI mode (no color, exit code)
#   ./scripts/workstation_audit_oracle.sh --json       # JSON output
#   ./scripts/workstation_audit_oracle.sh --gate G2    # Run single gate
#
# Exit codes:
#   0  — Score >= 95 (PASS)
#   1  — Score < 95  (FAIL)
#   2  — Fatal error (missing dependencies)
# ============================================================================
set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LUA_DIR="${CONFIG_ROOT}/lua"
readonly INIT_LUA="${CONFIG_ROOT}/init.lua"
readonly LOCKFILE="${CONFIG_ROOT}/lazy-lock.json"
readonly KITTY_CONF="${HOME}/.config/kitty/kitty.conf"
readonly TMUX_CONF="${HOME}/.config/tmux/tmux.conf"
readonly TMUX_CONF_ALT="${HOME}/.tmux.conf"

# Auto-detect NVIM_APPNAME from config directory name
# e.g., /Users/x0r/.config/nvim/x0r → NVIM_APPNAME=x0r
readonly NVIM_APPNAME_DETECTED="$(basename "$CONFIG_ROOT")"
export NVIM_APPNAME="${NVIM_APPNAME:-$NVIM_APPNAME_DETECTED}"

# SLA Thresholds
readonly SLA_STARTUP_HEADLESS_MS=10
readonly SLA_STARTUP_UI_MS=20
readonly SLA_STARTUP_RUNS=10
readonly SLA_TMUX_STATUS_MS=5
readonly PASS_THRESHOLD=95

# ── State ────────────────────────────────────────────────────────────────────
TOTAL_SCORE=0
TOTAL_MAX=0
CI_MODE=false
JSON_MODE=false
SINGLE_GATE=""
declare -a FINDINGS=()
declare -a GATE_RESULTS=()

# ── Argument parsing ────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ci)
      CI_MODE=true
      shift
      ;;
    --json)
      JSON_MODE=true
      shift
      ;;
    --gate)
      SINGLE_GATE="$2"
      shift 2
      ;;
    -h | --help)
      echo "Usage: $0 [--ci] [--json] [--gate G1..G6]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 2
      ;;
  esac
done

# ── Color support ────────────────────────────────────────────────────────────
if [[ "$CI_MODE" == true ]] || [[ ! -t 1 ]]; then
  RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET="" DIM=""
else
  RED="\033[0;31m" GREEN="\033[0;32m" YELLOW="\033[0;33m"
  BLUE="\033[0;34m" BOLD="\033[1m" RESET="\033[0m" DIM="\033[2m"
fi

# ── Logging ──────────────────────────────────────────────────────────────────
log_pass() { echo -e "${GREEN}  ✓ PASS${RESET}  $1"; }
log_fail() { echo -e "${RED}  ✗ FAIL${RESET}  $1"; }
log_warn() { echo -e "${YELLOW}  ⚠ WARN${RESET}  $1"; }
log_info() { echo -e "${BLUE}  ℹ INFO${RESET}  $1"; }
log_header() { echo -e "\n${BOLD}━━━ $1 ━━━${RESET}"; }

add_finding() {
  local severity="$1" gate="$2" msg="$3"
  FINDINGS+=("${severity}|${gate}|${msg}")
}

score_check() {
  local pts="$1" max="$2" msg="$3" pass="$4"
  TOTAL_MAX=$((TOTAL_MAX + max))
  if [[ "$pass" == "true" ]]; then
    TOTAL_SCORE=$((TOTAL_SCORE + pts))
    log_pass "$msg (+${pts}/${max})"
  else
    log_fail "$msg (+0/${max})"
    add_finding "FAIL" "$CURRENT_GATE" "$msg"
  fi
}

# ── Dependency check ────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  for cmd in nvim rg awk grep sed head tail wc stat; do
    if ! command -v "$cmd" &> /dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "FATAL: Missing required tools: ${missing[*]}"
    exit 2
  fi
}

# ============================================================================
# GATE 1: Neovim Startup & Runtime Latency Benchmark (20 pts)
# ============================================================================
gate_1() {
  CURRENT_GATE="G1"
  log_header "G1: Neovim Startup & Runtime Latency (20 pts)"

  local nvim_bin
  nvim_bin="$(command -v nvim)"

  # 1.1 Headless startup benchmark (10 pts)
  local sum=0 count=0 max_val=0
  local tmpfile
  tmpfile="$(mktemp)"

  for i in $(seq 1 "$SLA_STARTUP_RUNS"); do
    rm -f "$tmpfile" # Reset each iteration (--startuptime appends!)
    NVIM_APPNAME="$NVIM_APPNAME" "$nvim_bin" --headless --startuptime "$tmpfile" -c 'qa!' 2> /dev/null || true
    # Parse the "--- NVIM STARTED ---" line which contains total time
    local ms
    ms="$(grep 'NVIM STARTED' "$tmpfile" 2> /dev/null | head -1 | awk '{print $1}' || echo "")"
    if [[ -n "$ms" ]] && [[ "$ms" != "0" ]]; then
      sum="$(echo "$sum + $ms" | bc 2> /dev/null || echo "$sum")"
      count=$((count + 1))
      local gt
      gt="$(echo "$ms > $max_val" | bc -l 2> /dev/null || echo "0")"
      if [[ "$gt" -eq 1 ]]; then
        max_val="$ms"
      fi
    fi
  done
  rm -f "$tmpfile"

  if [[ $count -gt 0 ]]; then
    local mean
    mean="$(echo "scale=2; $sum / $count" | bc)"
    log_info "Headless startup: mean=${mean}ms, max=${max_val}ms (${count} runs)"

    local headless_pass
    headless_pass="$(echo "$mean <= $SLA_STARTUP_UI_MS" | bc -l)"
    score_check 10 10 "Headless startup mean ≤ ${SLA_STARTUP_UI_MS}ms (actual: ${mean}ms)" \
      "$([ "$headless_pass" -eq 1 ] && echo true || echo false)"

    # 1.2 Startup variance check (5 pts)
    local stddev_ok
    stddev_ok="$(echo "$max_val - $mean < 10" | bc -l)"
    score_check 5 5 "Startup variance (max-mean) < 10ms (actual: $(echo "$max_val - $mean" | bc)ms)" \
      "$([ "$stddev_ok" -eq 1 ] && echo true || echo false)"
  else
    score_check 0 10 "Headless startup benchmark (no data)" "false"
    score_check 0 5 "Startup variance (no data)" "false"
  fi

  # 1.3 vim.loader.enable() is line 1 of init.lua (5 pts)
  if [[ -f "$INIT_LUA" ]]; then
    local first_code
    first_code="$(grep -v '^\s*--' "$INIT_LUA" | grep -v '^\s*$' | head -1)"
    if echo "$first_code" | grep -q 'vim\.loader\.enable()'; then
      score_check 5 5 "vim.loader.enable() is first executable line in init.lua" "true"
    else
      score_check 0 5 "vim.loader.enable() is first executable line in init.lua (found: '${first_code}')" "false"
    fi
  else
    score_check 0 5 "init.lua exists" "false"
  fi
}

# ============================================================================
# GATE 2: SOLID Architecture & Hot-Path Non-Blocking Audit (20 pts)
# ============================================================================
gate_2() {
  CURRENT_GATE="G2"
  log_header "G2: SOLID Architecture & Non-Blocking Audit (20 pts)"

  # 2.1 core/ has zero requires from plugins/ (5 pts)
  local core_plugin_imports
  core_plugin_imports="$(rg -c 'require\s*\(\s*["\x27]plugins\.' "${LUA_DIR}/core/" -g '*.lua' 2> /dev/null || echo "0")"
  if [[ "$core_plugin_imports" == "0" ]] || [[ -z "$core_plugin_imports" ]]; then
    score_check 5 5 "core/ has zero imports from plugins/ (DIP compliance)" "true"
  else
    local violations
    violations="$(rg -n 'require\s*\(\s*["\x27]plugins\.' "${LUA_DIR}/core/" -g '*.lua' 2> /dev/null | head -5)"
    score_check 0 5 "core/ imports plugins/ — DIP violated: ${violations}" "false"
  fi

  # 2.2 defaults.lazy = true in lazy.nvim config (5 pts)
  local lazy_default
  lazy_default="$(rg -c 'lazy\s*=\s*true' "${LUA_DIR}/core/lazy.lua" 2> /dev/null || echo "0")"
  score_check 5 5 "defaults.lazy = true configured" \
    "$([ "${lazy_default:-0}" -ge 1 ] && echo true || echo false)"

  # 2.3 No synchronous vim.fn.system() in hot paths (5 pts)
  local sync_calls
  sync_calls="$(rg -n 'vim\.fn\.system\s*\(' "${LUA_DIR}/" -g '*.lua' 2> /dev/null | wc -l | tr -d ' ')"
  score_check 5 5 "Zero vim.fn.system() calls in lua/ (found: ${sync_calls})" \
    "$([ "$sync_calls" -eq 0 ] && echo true || echo false)"

  # 2.4 No io.popen() calls (3 pts)
  local iopopen_calls
  iopopen_calls="$(rg -n 'io\.popen\s*\(' "${LUA_DIR}/" -g '*.lua' 2> /dev/null | wc -l | tr -d ' ')"
  score_check 3 3 "Zero io.popen() calls in lua/ (found: ${iopopen_calls})" \
    "$([ "$iopopen_calls" -eq 0 ] && echo true || echo false)"

  # 2.5 Remote providers disabled (2 pts)
  local providers_disabled
  providers_disabled="$(rg -c 'loaded_.*_provider\s*=\s*0' "${LUA_DIR}/core/" -g '*.lua' 2> /dev/null || echo "0")"
  score_check 2 2 "Remote providers disabled (python3/ruby/perl/node)" \
    "$([ "${providers_disabled:-0}" -ge 4 ] && echo true || echo false)"
}

# ============================================================================
# GATE 3: DevSecOps & Supply-Chain Security Gate (20 pts)
# ============================================================================
gate_3() {
  CURRENT_GATE="G3"
  log_header "G3: DevSecOps & Supply-Chain Security (20 pts)"

  # 3.1 lazy-lock.json exists and pins 100% to 40-char SHAs (8 pts)
  if [[ -f "$LOCKFILE" ]]; then
    local total_plugins unpinned
    total_plugins="$(grep -c '"commit"' "$LOCKFILE" 2> /dev/null || echo "0")"
    unpinned="$(rg '"commit":\s*"[^"]{0,39}"' "$LOCKFILE" 2> /dev/null | wc -l | tr -d ' ')"
    # Also check for non-40-char commits
    local bad_shas
    bad_shas="$(grep '"commit"' "$LOCKFILE" | grep -v '"[0-9a-f]\{40\}"' | wc -l | tr -d ' ')"
    score_check 8 8 "lazy-lock.json: ${total_plugins} plugins, all pinned to 40-char SHAs (bad: ${bad_shas})" \
      "$([ "$bad_shas" -eq 0 ] && echo true || echo false)"
  else
    score_check 0 8 "lazy-lock.json exists" "false"
  fi

  # 3.2 No hardcoded API keys/secrets (5 pts)
  local secret_patterns='sk-ant-|sk-proj-|ANTHROPIC_API_KEY\s*=\s*["\x27][^"\x27]+|OPENAI_API_KEY\s*=\s*["\x27][^"\x27]+|ghp_[0-9a-zA-Z]{36}|gho_[0-9a-zA-Z]{36}'
  local secrets_found
  secrets_found="$(rg -n "$secret_patterns" "${LUA_DIR}/" -g '*.lua' 2> /dev/null | wc -l | tr -d ' ')"
  score_check 5 5 "Zero hardcoded secrets in lua/ (found: ${secrets_found})" \
    "$([ "$secrets_found" -eq 0 ] && echo true || echo false)"

  # 3.3 modelineexpr = false (3 pts)
  # Check if it's explicitly set or defaults are safe
  local modeline_expr
  modeline_expr="$(rg -c 'modelineexpr\s*=\s*true' "${LUA_DIR}/" -g '*.lua' 2> /dev/null || echo "0")"
  score_check 3 3 "modelineexpr not set to true (matches: ${modeline_expr})" \
    "$([ "${modeline_expr:-0}" -eq 0 ] && echo true || echo false)"

  # 3.4 Config directory permissions (2 pts)
  local config_perms
  config_perms="$(stat -f '%Lp' "$CONFIG_ROOT" 2> /dev/null || stat -c '%a' "$CONFIG_ROOT" 2> /dev/null || echo "777")"
  local perms_ok=false
  case "$config_perms" in
    700 | 750 | 755) perms_ok=true ;;
  esac
  score_check 2 2 "Config directory permissions ≤ 755 (actual: ${config_perms})" "$perms_ok"

  # 3.5 stylua.toml exists (2 pts)
  score_check 2 2 "stylua.toml exists for consistent formatting" \
    "$([ -f "${CONFIG_ROOT}/.stylua.toml" ] || [ -f "${CONFIG_ROOT}/stylua.toml" ] && echo true || echo false)"
}

# ============================================================================
# GATE 4: Kitty GPU & IPC Socket Security (15 pts)
# ============================================================================
gate_4() {
  CURRENT_GATE="G4"
  log_header "G4: Kitty GPU & IPC Socket Security (15 pts)"

  if [[ ! -f "$KITTY_CONF" ]]; then
    log_warn "kitty.conf not found at $KITTY_CONF — checking defaults"
    score_check 0 5 "kitty.conf exists for audit" "false"
    score_check 5 5 "Kitty allow_remote_control (no config = default 'no')" "true"
    score_check 5 5 "Kitty input/repaint delay (default values)" "true"
    return
  fi

  # 4.1 repaint_delay ≤ 10ms (5 pts)
  local repaint_delay
  repaint_delay="$(grep -E '^\s*repaint_delay\s+' "$KITTY_CONF" | awk '{print $2}' | tail -1)"
  repaint_delay="${repaint_delay:-10}"
  score_check 5 5 "repaint_delay ≤ 10 (actual: ${repaint_delay})" \
    "$([ "$repaint_delay" -le 10 ] 2> /dev/null && echo true || echo false)"

  # 4.2 input_delay ≤ 3ms (5 pts)
  local input_delay
  input_delay="$(grep -E '^\s*input_delay\s+' "$KITTY_CONF" | awk '{print $2}' | tail -1)"
  input_delay="${input_delay:-3}"
  score_check 5 5 "input_delay ≤ 3 (actual: ${input_delay})" \
    "$([ "$input_delay" -le 3 ] 2> /dev/null && echo true || echo false)"

  # 4.3 allow_remote_control (5 pts)
  local remote_control
  remote_control="$(grep -E '^\s*allow_remote_control\s+' "$KITTY_CONF" | awk '{print $2}' | tail -1)"
  remote_control="${remote_control:-no}"
  local rc_ok=false
  case "$remote_control" in
    no | socket-only | socket) rc_ok=true ;;
  esac
  score_check 5 5 "allow_remote_control ∈ {no, socket-only} (actual: ${remote_control})" "$rc_ok"
}

# ============================================================================
# GATE 5: Tmux Low-Latency & Socket Isolation (15 pts)
# ============================================================================
gate_5() {
  CURRENT_GATE="G5"
  log_header "G5: Tmux Low-Latency & Socket Isolation (15 pts)"

  local tmux_conf=""
  if [[ -f "$TMUX_CONF" ]]; then
    tmux_conf="$TMUX_CONF"
  elif [[ -f "$TMUX_CONF_ALT" ]]; then
    tmux_conf="$TMUX_CONF_ALT"
  fi

  if [[ -z "$tmux_conf" ]]; then
    log_warn "tmux.conf not found — checking live tmux config"
    # Try reading from live tmux session
    if command -v tmux &> /dev/null && tmux list-sessions &> /dev/null 2>&1; then
      local live_escape
      live_escape="$(tmux show-option -gv escape-time 2> /dev/null || echo "500")"
      score_check 5 5 "tmux escape-time = 0 (live: ${live_escape})" \
        "$([ "$live_escape" -eq 0 ] 2> /dev/null && echo true || echo false)"

      local live_focus
      live_focus="$(tmux show-option -gv focus-events 2> /dev/null || echo "off")"
      score_check 5 5 "tmux focus-events on (live: ${live_focus})" \
        "$([ "$live_focus" = "on" ] && echo true || echo false)"

      score_check 5 5 "tmux config file exists" "false"
    else
      score_check 0 5 "tmux escape-time (no tmux session)" "false"
      score_check 0 5 "tmux focus-events (no tmux session)" "false"
      score_check 0 5 "tmux config file exists" "false"
    fi
    return
  fi

  # 5.1 escape-time 0 (5 pts)
  local escape_time
  escape_time="$(grep -E '^\s*set\s+(-sg?\s+)?escape-time\s+' "$tmux_conf" | awk '{print $NF}' | tail -1)"
  escape_time="${escape_time:-500}"
  score_check 5 5 "escape-time 0 (actual: ${escape_time})" \
    "$([ "$escape_time" -eq 0 ] 2> /dev/null && echo true || echo false)"

  # 5.2 focus-events on (5 pts)
  local focus_events
  focus_events="$(grep -E '^\s*set\s+(-sg?\s+)?focus-events\s+' "$tmux_conf" | awk '{print $NF}' | tail -1)"
  focus_events="${focus_events:-off}"
  score_check 5 5 "focus-events on (actual: ${focus_events})" \
    "$([ "$focus_events" = "on" ] && echo true || echo false)"

  # 5.3 true-color passthrough (5 pts)
  local tc_set
  tc_set="$(grep -cE '(Tc|RGB|true-color|tmux-256color|screen-256color)' "$tmux_conf" 2> /dev/null || echo "0")"
  score_check 5 5 "True-color / terminal-overrides configured (matches: ${tc_set})" \
    "$([ "${tc_set:-0}" -ge 1 ] && echo true || echo false)"
}

# ============================================================================
# GATE 6: LLMOps Async & Credential Hygiene (10 pts)
# ============================================================================
gate_6() {
  CURRENT_GATE="G6"
  log_header "G6: LLMOps Async & Credential Hygiene (10 pts)"

  # 6.1 llmops/ directory exists (3 pts)
  if [[ -d "${LUA_DIR}/llmops" ]]; then
    score_check 3 3 "lua/llmops/ layer exists" "true"

    # 6.2 llmops/ uses only async patterns (4 pts)
    local sync_in_llmops
    sync_in_llmops="$(rg -n 'vim\.fn\.system\|io\.popen\|os\.execute' "${LUA_DIR}/llmops/" -g '*.lua' 2> /dev/null | wc -l | tr -d ' ')"
    score_check 4 4 "llmops/ uses async-only patterns (sync calls: ${sync_in_llmops})" \
      "$([ "$sync_in_llmops" -eq 0 ] && echo true || echo false)"
  else
    score_check 0 3 "lua/llmops/ layer exists" "false"
    score_check 0 4 "llmops/ async patterns (layer missing)" "false"
  fi

  # 6.3 No tokens in tmux show-environment (3 pts)
  if command -v tmux &> /dev/null && tmux list-sessions &> /dev/null 2>&1; then
    local tmux_secrets
    tmux_secrets="$(tmux show-environment 2> /dev/null | grep -iE 'API_KEY|TOKEN|SECRET|sk-ant|sk-proj' | wc -l | tr -d ' ')"
    score_check 3 3 "Zero secrets in tmux show-environment (found: ${tmux_secrets})" \
      "$([ "$tmux_secrets" -eq 0 ] && echo true || echo false)"
  else
    log_info "tmux not running — skipping environment check"
    score_check 3 3 "tmux environment (not running, safe by default)" "true"
  fi
}

# ============================================================================
# Main execution
# ============================================================================
main() {
  check_deps

  echo -e "${BOLD}"
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║       x0r/nvim — Workstation Audit Oracle v1.0.0           ║"
  echo "║       6-Gate Multi-Domain Verification Harness              ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
  echo "  Config root:   ${CONFIG_ROOT}"
  echo "  Lua dir:       ${LUA_DIR}"
  echo "  NVIM_APPNAME:  ${NVIM_APPNAME}"
  echo "  Timestamp:     $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo ""

  if [[ -n "$SINGLE_GATE" ]]; then
    case "$SINGLE_GATE" in
      G1 | g1) gate_1 ;;
      G2 | g2) gate_2 ;;
      G3 | g3) gate_3 ;;
      G4 | g4) gate_4 ;;
      G5 | g5) gate_5 ;;
      G6 | g6) gate_6 ;;
      *)
        echo "Unknown gate: $SINGLE_GATE (valid: G1..G6)"
        exit 2
        ;;
    esac
  else
    gate_1
    gate_2
    gate_3
    gate_4
    gate_5
    gate_6
  fi

  # ── Final Score ──────────────────────────────────────────────────────────
  echo ""
  log_header "FINAL SCORE"

  local pct=0
  if [[ $TOTAL_MAX -gt 0 ]]; then
    pct=$((TOTAL_SCORE * 100 / TOTAL_MAX))
  fi

  local status_color="$RED"
  local status_text="FAIL"
  if [[ $pct -ge $PASS_THRESHOLD ]]; then
    status_color="$GREEN"
    status_text="PASS"
  elif [[ $pct -ge 80 ]]; then
    status_color="$YELLOW"
    status_text="MARGINAL"
  fi

  echo -e "  ${BOLD}Score: ${status_color}${TOTAL_SCORE}/${TOTAL_MAX} (${pct}%)${RESET}"
  echo -e "  ${BOLD}Status: ${status_color}${status_text}${RESET} (threshold: ${PASS_THRESHOLD}%)"

  # ── Findings summary ────────────────────────────────────────────────────
  if [[ ${#FINDINGS[@]} -gt 0 ]]; then
    echo ""
    log_header "FINDINGS (${#FINDINGS[@]})"
    for f in "${FINDINGS[@]}"; do
      IFS='|' read -r sev gate msg <<< "$f"
      echo -e "  ${RED}[${gate}]${RESET} ${msg}"
    done
  fi

  # ── JSON output ────────────────────────────────────────────────────────
  if [[ "$JSON_MODE" == true ]]; then
    local findings_json="["
    local first=true
    for f in "${FINDINGS[@]}"; do
      IFS='|' read -r sev gate msg <<< "$f"
      if [[ "$first" == true ]]; then first=false; else findings_json+=","; fi
      findings_json+="{\"severity\":\"${sev}\",\"gate\":\"${gate}\",\"message\":\"${msg}\"}"
    done
    findings_json+="]"

    cat << EOF
{
  "overall_score": ${pct},
  "points": ${TOTAL_SCORE},
  "max_points": ${TOTAL_MAX},
  "status": "${status_text}",
  "threshold": ${PASS_THRESHOLD},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "findings": ${findings_json}
}
EOF
  fi

  # ── Exit code ──────────────────────────────────────────────────────────
  if [[ $pct -ge $PASS_THRESHOLD ]]; then
    exit 0
  else
    exit 1
  fi
}

main "$@"
