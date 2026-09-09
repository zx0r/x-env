# ---
# schema: "mdd-node-v1"
# id: "functions/dns-audit.fish"
# title: "DNS Infrastructure Auditor"
# layer: "Functions"
# responsibility: "Performs DNS health check, processes listening on port 53, system DNS settings, and local cache query latency"
# dependencies: ["lsof", "scutil", "dig", "awk"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "dns"]
# ---

function dns-audit --description "Comprehensive DNS health check"
    echo "━━━ Listening Processes ━━━"
    # Disable port name resolution for speed
    sudo lsof -nP -i :53 | grep LISTEN

    echo -e "\n━━━ System Resolution Path ━━━"
    # Check DNS routing settings via macOS scutil
    scutil --dns | grep nameserver | head -n 1

    echo -e "\n━━━ Cache Performance (127.0.0.2) ━━━"
    # Make a warm query check
    dig google.com @127.0.0.2 >/dev/null
    set -l query_time (dig google.com @127.0.0.2 | awk '/Query time:/ {print $4, $5}')

    if test -n "$query_time"
        echo "Local Cache Latency: $query_time"
        set -l query_parts (string split ' ' -- "$query_time")
        if test (count $query_parts) -ge 1; and string match -q -r '^[0-9]+$' -- "$query_parts[1]"
            if test "$query_parts[1]" -le 1
                echo (set_color green)"✅ Hyper-Caching is active (Elite Speed)"(set_color normal)
            else
                echo (set_color yellow)"⚠️  Caching might be slow or bypassed (latency is high)"(set_color normal)
            end
        else
            echo (set_color yellow)"⚠️  Unexpected latency format: $query_time"(set_color normal)
        end
    else
        echo (set_color red)"❌ Local cache (127.0.0.2) is not responding or unreachable"(set_color normal)
    end
end

