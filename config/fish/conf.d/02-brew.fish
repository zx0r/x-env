# ---
# schema: "mdd-node-v1"
# id: "conf.d/02-brew.fish"
# title: "Homebrew Subsystem & Environment Architecture"
# layer: "Foundation (00-09)"
# responsibility: "Configures Homebrew prefixes statically, hardens SSL/TLS, eliminates telemetry, and tunes cache/update lifecycles"
# dependencies: ["conf.d/00-xdg.fish"]
# backlinks: ["config.fish", "conf.d/03-path.fish", "functions/brew.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-10-03"
# last_commit: "pending"
# tags: ["homebrew", "environment", "performance", "security", "zero-overhead"]
# ---

# ==============================================================================
# 🍺 HOMEBREW PLATFORM SUBSYSTEM
# ------------------------------------------------------------------------------
# Layer: Foundation | Contract: Zero-Fork & Zero-Overhead | Target: Apple Silicon
# ------------------------------------------------------------------------------
# Responsibilities:
# 1. Static Prefix Mapping: Eliminates 'brew shellenv' Ruby fork (~40ms startup SLA)
# 2. Strict Telemetry Elimination: Unconditionally exports HOMEBREW_NO_ANALYTICS=1
# 3. Cache & Disk Hygiene: Enforces 30-day bottle prune to protect NVMe storage
# 4. Supply-Chain & Network Hardening: Locks CA-bundle to brewed TLS and blocks HTTP
# 5. Interactive Integrations: Delegated to functions/brew.fish JIT wrapper
# ==============================================================================

# 1. macOS Host Architecture Guard (Zero execution overhead on Linux/BSD)
test -d /System/Library; or return 0

# 2. Homebrew Presence & Static Prefix Mapping (Zero-Fork SLA: saves ~40ms vs 'brew shellenv')
if test -d /opt/homebrew
    set -gx HOMEBREW_PREFIX /opt/homebrew
    set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
    set -gx HOMEBREW_REPOSITORY /opt/homebrew
else if test -d /usr/local/Homebrew
    set -gx HOMEBREW_PREFIX /usr/local
    set -gx HOMEBREW_CELLAR /usr/local/Cellar
    set -gx HOMEBREW_REPOSITORY /usr/local/Homebrew
else
    if status is-interactive
        echo "⚠ Homebrew not found. Run: mise run L1_bootstrap" >&2
    end
    return 0
end

set -gx HOMEBREW_BREWFILE "$XDG_CONFIG_HOME/brewfile/Brewfile"

# 3. Privacy & Telemetry Hardening (Global Export: Active for subshells, scripts & launchd)
set -gx HOMEBREW_NO_ANALYTICS 1

# 4. Core Performance & Update Latency Governors
set -gx HOMEBREW_NO_AUTO_UPDATE 1              # Suppress git fetch on every CLI command
set -gx HOMEBREW_AUTO_UPDATE_SECS 604800       # 7-day TTL for formula index checks
set -gx HOMEBREW_API_AUTO_UPDATE_SECS 86400    # 24-hour TTL for JSON API index
set -gx HOMEBREW_INSTALL_FROM_API 1            # Fetch JSON API instead of heavy Git taps
set -gx HOMEBREW_NO_ENV_HINTS 1                # Canonical flag: suppress shell export hints

# 5. Security Hardening & Artifact Provenance
set -gx HOMEBREW_NO_INSECURE_REDIRECT 1        # Disallow HTTP downgrades
set -gx HOMEBREW_ARTIFACT_DOMAIN_NO_FALLBACK 1 # Fail closed on private binary cache issues
set -gx HOMEBREW_FORCE_BREWED_CA_CERTIFICATES 1 # Force isolated, audited CA store

# 6. Disk Space & Cache Management Governors
set -gx HOMEBREW_CLEANUP_MAX_AGE_DAYS 30       # Retain cached bottles max 30 days (default: 120)
set -gx HOMEBREW_CLEANUP_PERIODIC_FULL_DAYS 30 # Run full prune every 30 days during upgrades

# 7. Network & Transport Isolation (Brewed Curl + Modern TLS)
set -gx HOMEBREW_CURL_RETRIES 3
set -gx HOMEBREW_FORCE_VENDOR_RUBY 1

set -l homebrew_curl_bin "$HOMEBREW_PREFIX/opt/curl/bin"
if test -x "$homebrew_curl_bin/curl"
    set -gx CURL_HOME "$XDG_CONFIG_HOME/curl"
    set -gx CURL_BIN "$homebrew_curl_bin"
    set -gx CURL_CA_BUNDLE "$HOMEBREW_PREFIX/etc/ca-certificates/cert.pem"
    set -gx SSL_CERT_FILE "$CURL_CA_BUNDLE"
    set -gx HOMEBREW_FORCE_BREWED_CURL 1
else
    set -gx SSL_CERT_FILE "$HOMEBREW_PREFIX/etc/ca-certificates/cert.pem"
end
# 8. Interactive Wrappers
# Delegated to functions/brew.fish (Zero-Fork SLA: JIT loads brew-wrap on command execution)
