# ---
# schema: "mdd-node-v1"
# id: "functions/dns_maintenance.fish"
# title: "DNS Infrastructure Maintenance"
# layer: "Functions"
# responsibility: "Updates hosts file, updates DNSCrypt blocklists, flushes macOS DNS cache, and verifies current DNS settings"
# dependencies: ["curl", "dnscrypt-proxy", "killall", "networksetup", "scutil"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "dns", "system"]
# ---

function dns_maintenance --description "Update hosts, DNSCrypt blocklist, and flush DNS cache"
    if not command -sq curl
        echo "Error: 'curl' is required but not installed." >&2
        return 1
    end

    echo "━━━ Updating /etc/hosts (StevenBlack hosts list) ━━━"
    set -l temp_hosts (mktemp)
    if curl -sSf --connect-timeout 5 --max-time 20 https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts -o "$temp_hosts"
        sudo cp "$temp_hosts" /etc/hosts
        echo "✅ /etc/hosts updated successfully"
    else
        echo "❌ Failed to download new hosts file. Keeping existing /etc/hosts." >&2
    end
    rm -f -- "$temp_hosts"

    # Resolve Homebrew prefix
    set -l brew_prefix "/opt/homebrew"
    if test -n "$HOMEBREW_PREFIX"
        set brew_prefix "$HOMEBREW_PREFIX"
    else if command -sq brew
        set brew_prefix (brew --prefix)
    end

    set -l dnscrypt_conf "$brew_prefix/etc/dnscrypt-proxy.toml"
    if test -f "$dnscrypt_conf"; and command -sq dnscrypt-proxy
        echo -e "\n━━━ Updating DNSCrypt blocklists ━━━"
        dnscrypt-proxy -config "$dnscrypt_conf" -update
    else
        echo -e "\n⚠️  dnscrypt-proxy not found or config missing at $dnscrypt_conf"
    end

    echo -e "\n━━━ Flushing DNS cache ━━━"
    if sudo killall -HUP mDNSResponder
        echo "✅ DNS Cache flushed (mDNSResponder)"
    else
        echo "❌ Failed to flush DNS cache" >&2
    end

    echo -e "\n━━━ Verifying Configuration ━━━"
    if networksetup -getdnsservers Wi-Fi >/dev/null 2>&1
        networksetup -getdnsservers Wi-Fi
    else
        echo "Wi-Fi interface not available or not configured for custom DNS."
    end
    scutil --dns | grep 'nameserver\[0\]' | head -n 5
end

