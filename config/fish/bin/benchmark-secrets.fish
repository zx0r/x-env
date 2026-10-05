#!/usr/bin/env fish

function get_ms
    python3 -c 'import time; print(int(time.time() * 1000))'
end

# Подготовка тестовых данных
for i in (seq 1 100)
    echo "KEY_$i=VALUE_$i"
end > /tmp/tokens.env

echo '{"TEST_KEY":"123"}' > /tmp/sops_bench_dummy.json
# Шифруем тестовый файл для честного теста SOPS
sops -e --input-type json --output-type json /tmp/sops_bench_dummy.json > /tmp/sops_bench.enc.json 2>/dev/null

echo "==========================================="
echo "   BENCHMARK: 100 SEQUENTIAL READS         "
echo "==========================================="

echo -e "\n1. RAM Cache Architecture (/tmp/tokens.env + native string match):"
set start (get_ms)
for i in (seq 1 100)
    set -l safe_i (string escape --style=regex "$i")
    string match -r "^KEY_$safe_i=(.*)" < /tmp/tokens.env >/dev/null
end
set end (get_ms)
set diff (math $end - $start)
echo "Total time (100 reads): $diff ms"
echo "Average time per read: "(math $diff / 100)" ms"

echo -e "\n2. macOS Keychain (/usr/bin/security):"
command /usr/bin/security add-generic-password -s "TEST_KEY_BENCH" -a "$USER" -w "123" 2>/dev/null
set start (get_ms)
for i in (seq 1 100)
    command /usr/bin/security find-generic-password -s "TEST_KEY_BENCH" -a "$USER" -w 2>/dev/null >/dev/null
end
set end (get_ms)
set diff (math $end - $start)
echo "Total time (100 reads): $diff ms"
echo "Average time per read: "(math $diff / 100)" ms"
command /usr/bin/security delete-generic-password -s "TEST_KEY_BENCH" -a "$USER" 2>/dev/null

echo -e "\n3. SOPS Direct Decryption (sops -d):"
set start (get_ms)
for i in (seq 1 100)
    sops -d --output-type json /tmp/sops_bench.enc.json 2>/dev/null >/dev/null
end
set end (get_ms)
set diff (math $end - $start)
echo "Total time (100 reads): $diff ms"
echo "Average time per read: "(math $diff / 100)" ms"
echo "==========================================="
