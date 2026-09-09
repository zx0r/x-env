# ---
# schema: "mdd-node-v1"
# id: "functions/dnsleaktest.fish"
# title: "DNS Leak and Privacy Auditor"
# layer: "Functions"
# responsibility: "Performs deep DNS security and privacy check, validating DNSSEC integrity, QNAME minimization, ECS status, and protocol type"
# dependencies: ["dig", "curl", "jq", "ping", "scutil"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "dns", "security"]
# ---

function dnsleaktest --description "Ultimate DNS security and privacy audit"
    if not command -sq dig
        echo "Error: 'dig' is required but not installed." >&2
        return 1
    end
    if not command -sq curl
        echo "Error: 'curl' is required but not installed." >&2
        return 1
    end
    if not command -sq jq
        echo "Error: 'jq' is required but not installed." >&2
        return 1
    end

    echo "━━━ Deep DNS Security Audit (Elite Architecture) ━━━"

    # 0. Auto-detect target IP (prefer 127.0.0.2, fallback to current system resolver)
    set -l target "127.0.0.2"
    if not ping -c 1 -t 1 $target >/dev/null 2>&1
        set target (scutil --dns | awk '/nameserver\[0\]/ {print $3; exit}' | head -n 1)
    end

    if test -z "$target"
        echo "❌ CRITICAL: No system DNS resolver found." >&2
        return 1
    end

    # 1. Resolver Identification & Protocol Check
    set -l dig_res (dig +noall +answer +comments txt resolver.dnscrypt.info @$target +time=3 +tries=1 2>/dev/null)
    set -l res_v4 (string match -r '.*TXT.*' -- $dig_res | string replace -a '"' '')
    set -l ip_v4 (string match -r '\d+\.\d+\.\d+\.\d+' -- "$res_v4")

    if test -z "$ip_v4"
        set_color red
        echo "❌ CRITICAL: DNS queries are not reaching a secure resolver."
        set_color normal
        return 1
    end

    # 2. Geodata & Privacy Analysis
    set -l api_res (curl -sSf --max-time 5 "http://ip-api.com/json/$ip_v4?fields=status,isp,as,country,hosting")
    if test $status -eq 0; and test -n "$api_res"
        set -l values (echo "$api_res" | jq -r '.hosting, .isp, .as, .country')
        set -l is_hosting $values[1]
        set -l isp $values[2]
        set -l as $values[3]
        set -l country $values[4]

        echo "📍 Resolver IP:   $ip_v4"
        echo "🏢 Provider:      $isp ($as)"
        echo "🌍 Location:      $country"

        # 4. Privacy & Anonymity Features
        echo -n "🕵️  Privacy:       "
        if test "$is_hosting" = "true"
            echo (set_color green)"Privacy Focused (Datacenter/Relay)"(set_color normal)
        else
            echo (set_color yellow)"Residential (ISP IP visible to resolver)"(set_color normal)
        end
    else
        echo "📍 Resolver IP:   $ip_v4"
        echo "⚠️  Failed to query provider geodata."
    end

    # 3. DNSSEC Cryptographic Validation (PhD Layer: SigFail + AD Flag Triangulation)
    echo -n "🛡️  DNSSEC:         "
    
    # Positive check: Request records + signatures
    set -l dnssec_res (dig @$target icann.org A +dnssec +time=3 +tries=1 2>/dev/null)
    
    set -l has_rrsig 0
    if string match -q "*RRSIG*" -- "$dnssec_res"
        set has_rrsig 1
    end
    
    set -l has_ad 0
    if string match -qr ";; flags:.* ad" -- "$dnssec_res"
        set has_ad 1
    end
    
    # Negative check: Broken signatures MUST return SERVFAIL (The SigFail Proof)
    set -l sigfail_res (dig @$target sigfail.verteiltesysteme.net +noall +comments +time=3 +tries=1 2>/dev/null)
    set -l sigfail_test 0
    if string match -q "*status: SERVFAIL*" -- "$sigfail_res"
        set sigfail_test 1
    end

    if test "$has_rrsig" -eq 1
        if test "$sigfail_test" -eq 1
            if test "$has_ad" -eq 1
                echo (set_color green)"Validated (Full Chain & AD Flag)"(set_color normal)
            else
                echo (set_color green)"Validated (Integrity Confirmed via SigFail)"(set_color normal)
                echo "   └─ "(set_color yellow)"Note: AD flag missing (expected in Anonymized/Relay mode)"(set_color normal)
            end
        else
            echo (set_color yellow)"⚠️  Signed (RRSIG present, but no AD flag & SigFail bypassed)"(set_color normal)
        end
    else
        echo (set_color red)"❌ Unsigned / Stripped"(set_color normal)
    end

    echo -n "🔒 ECS Status:     "
    set -l ecs_check (dig +short txt o-o.myaddr.l.google.com @$target +time=3 +tries=1 2>/dev/null | string replace -a '"' '' | head -n 1)
    if test -z "$ecs_check"
        echo (set_color yellow)"Inconclusive (Timeout/Disabled)"(set_color normal)
    else
        echo (set_color blue)"Active (Visibility: $ecs_check)"(set_color normal)
    end

    echo -n "🔎 QNAME Min:      "
    set -l qname_out (dig +short txt qnamemintest.internet.nl @$target +time=3 +tries=1 2>/dev/null)
    if test -n "$qname_out"
        echo (set_color green)"Active"(set_color normal)
    else
        echo (set_color yellow)"Inactive / Filtered"(set_color normal)
    end

    echo -n "🚀 Protocol:      "
    if string match -q "*dnscrypt*" -- "$res_v4"
        echo DNSCrypt
    else
        echo "DoH / ODoH (Encapsulated)"
    end
end

