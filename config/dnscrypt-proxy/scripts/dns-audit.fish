# macOS DNS Diagnostic & Cache Latency Audit (127.0.0.1)
function dns-audit --description 'Comprehensive DNS health check'
    echo "━━━ Listening Processes ━━━"
    # Use -nP to prevent hanging on port/hostname reverse lookups
    sudo lsof -nP -i :53 | grep LISTEN

    echo \n"━━━ System Resolution Path ━━━"
    # Inspect active system nameserver from macOS Dynamic Store (SCDynamicStore)
    scutil --dns | grep nameserver | head -n 1

    echo \n"━━━ Cache Performance (127.0.0.1) ━━━"
    # Measure cached query latency against localhost (127.0.0.1)
    dig google.com @127.0.0.1 >/dev/null
    set -l query_time (dig google.com @127.0.0.1 | awk '/Query time:/ {print $4, $5}')
    echo "Local Cache Latency: $query_time"

    if test (string split ' ' $query_time)[1] -le 1
        echo (set_color green)"✅ Local DNS cache hit (< 2ms)"(set_color normal)
    else
        echo (set_color yellow)"⚠️  Cache miss or upstream resolution delay"(set_color normal)
    end
end
