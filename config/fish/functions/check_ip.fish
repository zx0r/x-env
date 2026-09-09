# ---
# schema: "mdd-node-v1"
# id: "functions/check_ip.fish"
# title: "Public IP Geolocation Checker"
# layer: "Functions"
# responsibility: "Retrieves public IP and displays geolocation details (City, Country, ISP) with color output"
# dependencies: ["curl", "jq"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "utility"]
# ---

function check_ip --description "Check public IP address and geolocation details"
    if not command -sq curl
        echo "Error: 'curl' is required but not installed." >&2
        return 1
    end

    if not command -sq jq
        echo "Error: 'jq' is required but not installed." >&2
        return 1
    end

    # Retrieve public IP
    set -l pubip (curl -sS --connect-timeout 3 --max-time 5 http://ifconfig.me/ip)
    if test $status -ne 0; or test -z "$pubip"
        echo "Error: Failed to retrieve public IP address." >&2
        return 1
    end

    # Retrieve geolocation data
    set -l request (curl -sS --connect-timeout 3 --max-time 5 "http://ip-api.com/json/$pubip")
    if test $status -ne 0; or test -z "$request"
        echo "Error: Failed to retrieve geolocation data for IP $pubip." >&2
        return 1
    end

    # Parse fields using jq
    set -l values (echo "$request" | jq -r '.query, .city, .country, .isp')
    if test (count $values) -lt 4
        echo "Error: Failed to parse geolocation data." >&2
        return 1
    end

    set -l ip $values[1]
    set -l city $values[2]
    set -l country $values[3]
    set -l isp $values[4]

    # Colors
    set -l bpurple (set_color --bold purple)
    set -l bgreen (set_color --bold green)
    set -l bblue (set_color --bold blue)
    set -l bred (set_color --bold red)
    set -l normal (set_color normal)

    printf "%sIP: %s%s %sCity: %s%s %sCountry: %s%s %sISP: %s%s\n" \
        "$bpurple" "$ip" "$normal" \
        "$bgreen" "$city" "$normal" \
        "$bblue" "$country" "$normal" \
        "$bred" "$isp" "$normal"
end

