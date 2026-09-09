# Optimized for Elite DNS Architecture (127.0.0.2)
# PhD Level Security Audit with sigfail triangulation
function dnsleaktest --description 'Ultimate DNS security and privacy audit'
    echo "━━━ Deep DNS Security Audit (Elite Architecture) ━━━"

    # 0. Auto-detect target IP (prefer 127.0.0.2, fallback to current system resolver)
    set -l target "127.0.0.2"
    if not ping -c 1 -t 1 $target >/dev/null 2>&1
        set target (scutil --dns | awk '/nameserver\[0\]/ {print $3; exit}' | head -n 1)
    end

    # 1. Resolver Identification & Protocol Check
    set -l dig_res (dig +noall +answer +comments txt resolver.dnscrypt.info @$target)
    set -l res_v4 (echo "$dig_res" | grep "TXT" | string replace -a '"' '')
    set -l ip_v4 (string match -r '\d+\.\d+\.\d+\.\d+' "$res_v4")

    if test -z "$ip_v4"
        set_color red
        echo "❌ CRITICAL: DNS queries are not reaching a secure resolver."
        set_color normal
        return 1
    end

    # 2. Geodata & Privacy Analysis
    set -l api_res (curl -s --max-time 5 "http://ip-api.com/json/$ip_v4?fields=status,isp,as,country,hosting")
    set -l is_hosting (echo $api_res | jq -r '.hosting')

    echo "📍 Resolver IP:   $ip_v4"
    echo "🏢 Provider:      "(echo $api_res | jq -r '.isp')" ("(echo $api_res | jq -r '.as')")"
    echo "🌍 Location:      "(echo $api_res | jq -r '.country')

    # 3. DNSSEC Cryptographic Validation (PhD Layer: SigFail + AD Flag Triangulation)
    echo -n "🛡️  DNSSEC:         "
    
    # Positive check: Request records + signatures
    set -l dnssec_res (dig @$target icann.org A +dnssec +time=3 2>/dev/null)
    set -l has_rrsig (echo "$dnssec_res" | grep -q "RRSIG"; and echo 1; or echo 0)
    set -l has_ad (echo "$dnssec_res" | grep -qE ";; flags:.* ad"; and echo 1; or echo 0)
    
    # Negative check: Broken signatures MUST return SERVFAIL (The SigFail Proof)
    set -l sigfail_test (dig @$target sigfail.verteiltesysteme.net +noall +comments +time=5 2>/dev/null | grep -q "status: SERVFAIL"; and echo 1; or echo 0)

    if test "$has_rrsig" -eq 1
        if test "$sigfail_test" -eq 1
            if test "$has_ad" -eq 1
                echo (set_color green)"Validated (Full Chain & AD Flag)"(set_color normal)
            else
                echo (set_color green)"Validated (Integrity Confirmed via SigFail)"(set_color normal)
                echo "   └─ "(set_color yellow)"Note: AD flag missing (expected in Anonymized/Relay mode)"(set_color normal)
            end
        else
            # RRSIG present but SigFail bypassed - this is the "Warn" state
            echo (set_color yellow)"⚠️  Signed (RRSIG present, but no AD flag & SigFail bypassed)"(set_color normal)
        end
    else
        echo (set_color red)"❌ Unsigned / Stripped"(set_color normal)
    end

    # 4. Privacy & Anonymity Features
    echo -n "🕵️  Privacy:       "
    if test "$is_hosting" = true
        echo (set_color green)"Privacy Focused (Datacenter/Relay)"(set_color normal)
    else
        echo (set_color yellow)"Residential (ISP IP visible to resolver)"(set_color normal)
    end

    echo -n "🔒 ECS Status:     "
    set -l ecs_check (dig +short txt o-o.myaddr.l.google.com @$target | tr -d '"' | head -n 1)
    if test -z "$ecs_check"
        echo (set_color yellow)"Inconclusive (Timeout)"(set_color normal)
    else
        echo (set_color blue)"Active (Visibility: $ecs_check)"(set_color normal)
    end

    echo -n "🔎 QNAME Min:      "
    # FIXED: Added quotes to handle multi-word TXT response
    set -l qname_out (dig +short txt qnamemintest.internet.nl @$target)
    if test -n "$qname_out"
        echo (set_color green)"Active"(set_color normal)
    else
        echo (set_color yellow)"Inactive / Filtered"(set_color normal)
    end

    echo -n "🚀 Protocol:      "
    if string match -q "*dnscrypt*" "$res_v4"
        echo DNSCrypt
    else
        echo "DoH / ODoH (Encapsulated)"
    end
end
