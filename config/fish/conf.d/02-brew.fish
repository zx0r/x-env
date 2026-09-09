# ---
# schema: "mdd-node-v1"
# id: "conf.d/02-brew.fish"
# title: "Homebrew Environment Mapping"
# layer: "Foundation (00-09)"
# responsibility: "Configures Homebrew prefixes statically to bypass Ruby shellenv forks"
# dependencies: ["conf.d/01-path.fish"]
# backlinks: ["config.fish"]
# created_at: "2026-06-24"
# updated_at: "2026-06-26"
# last_commit: "a7e6fbd6903547553ea6928408916059d72f21de"
# tags: ["homebrew", "environment", "performance"]
# ---

# 1. macOS Safeguard (Ensures script doesn't execute on Linux or non-macOS environments)
# Note: Use 'return 0' instead of 'exit' so that sourcing this script does not close the terminal
test -d /System/Library; or return 0

# 2. Self-Healing: Auto-Installer Check (Guarded for interactive shells only)
if status is-interactive
    if not test -x /opt/homebrew/bin/brew
        echo "🍺 Homebrew not found. Installing..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    end
end

# 3. Static Prefix Mappings (Bypasses brew shellenv Ruby execution - saves ~40ms)
set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
set -gx HOMEBREW_REPOSITORY /opt/homebrew
set -gx HOMEBREW_BREWFILE "$XDG_CONFIG_HOME/brewfile/Brewfile"


# 5. Core Performance & Cache Optimizations
set -gx HOMEBREW_BOOTSNAP 1 # Enable Ruby Bootsnap caching for faster CLI load
set -gx HOMEBREW_NO_AUTO_UPDATE 1 # Disable automatic git fetch checks on every command
set -gx HOMEBREW_AUTO_UPDATE_SECS 604800 # Week-long update TTL for manual update checks
set -gx HOMEBREW_API_AUTO_UPDATE_SECS 86400 # Day-long API TTL for metadata check
set -gx HOMEBREW_INSTALL_FROM_API 1 # Fetch JSON metadata instead of cloning heavy Git taps

# 6. Privacy & UX Preferences
set -gx HOMEBREW_ENV_HINTS 0 # Suppress post-install shell environment suggestions
# set -gx HOMEBREW_UPGRADE_GREEDY 1              # OPTIONAL: Comment out if 'brew upgrade' is too slow (re-downloads auto-updating casks like Chrome/VSCode)

# 7. Security Hardening & Provenance Verification
# set -gx HOMEBREW_VERIFY_ATTESTATIONS 1         # OPTIONAL: Comment out if download verification is too slow (queries GitHub/Cosign APIs)
set -gx HOMEBREW_NO_INSECURE_REDIRECT 1 # Prevent HTTPS to HTTP redirects
set -gx HOMEBREW_ARTIFACT_DOMAIN_NO_FALLBACK 1 # Fail closed on private binary cache issues

# 8. Optimized Network & Download Settings
set -gx HOMEBREW_CURL_RETRIES 3 # Retry failed downloads up to 3 times
# set -gx HOMEBREW_FORCE_BREWED_GIT 1            # OPTIONAL: Comment out to use macOS system Git (faster, uses native Keychain auth)
# set -gx HOMEBREW_FORCE_BREWED_CURL 1           # OPTIONAL: Comment out to use macOS system Curl (better SSL/network performance)
set -gx HOMEBREW_FORCE_VENDOR_RUBY 1 # Force Homebrew-compiled Ruby
set -gx HOMEBREW_FORCE_BREWED_CA_CERTIFICATES 1 # Force secure brewed CA certificates
set -gx SSL_CERT_FILE "$HOMEBREW_PREFIX/etc/ca-certificates/cert.pem"

# 9. Optional Integrations (Guarded for interactive shells only)
if status is-interactive
    # Homebrew-file wrapper (automatically keeps Brewfile in sync with installations)
    if test -f "$HOMEBREW_PREFIX/etc/brew-wrap.fish"
        source "$HOMEBREW_PREFIX/etc/brew-wrap.fish"
    end
end
