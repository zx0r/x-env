# Optimized for Elite DNS Architecture (127.0.0.2)
function dns-audit --description 'Comprehensive DNS health check'
    echo "━━━ Listening Processes ━━━"
    # Используем -n для ускорения (отключаем резолв имен самих портов)
    sudo lsof -nP -i :53 | grep LISTEN

    echo \n"━━━ System Resolution Path ━━━"
    # scutil дает понять, куда macOS реально шлет запросы
    scutil --dns | grep nameserver | head -n 1

    echo \n"━━━ Cache Performance (127.0.0.2) ━━━"
    # Делаем два замера: холодный и горячий (на адрес 127.0.0.2)
    dig google.com @127.0.0.2 >/dev/null
    set -l query_time (dig google.com @127.0.0.2 | awk '/Query time:/ {print $4, $5}')
    echo "Local Cache Latency: $query_time"

    if test (string split ' ' $query_time)[1] -le 1
        echo (set_color green)"✅ Hyper-Caching is active (Elite Speed)"(set_color normal)
    else
        echo (set_color yellow)"⚠️  Caching might be slow or bypassed"(set_color normal)
    end
end
