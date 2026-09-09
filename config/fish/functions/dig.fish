# ---
# schema: "mdd-node-v1"
# id: "functions/dig.fish"
# title: "Smart DNS Lookup Wrapper"
# layer: "Functions"
# responsibility: "Wraps dig to perform multi-record type lookups on a single domain, or falls back to system dig for standard queries"
# dependencies: ["dig"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "dns"]
# ---

function dig --description "Perform DNS lookup (multi-type lookup for single domain, or standard dig fallback)"
    if test (count $argv) -eq 1; and not string match -q -r '^[@-]' -- $argv[1]
        set -l domain $argv[1]
        set -l server "1.1.1.1"
        set -l types A AAAA CNAME MX NS PTR SOA SRV TXT DNSKEY DS NSEC NSEC3 NSEC3PARAM RRSIG AFSDB CAA CERT DHCID DNAME HINFO LOC NAPTR TLSA

        for type in $types
            set -l result (command dig @$server +short -- $type "$domain" 2>/dev/null)
            if test -n "$result"
                set_color --bold green
                printf "%-12s" "$type:"
                set_color normal
                echo " "(string join ", " $result)
            end
        end
    else
        command dig $argv
    end
end
