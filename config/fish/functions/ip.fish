# ---
# schema: "mdd-node-v1"
# id: "functions/ip.fish"
# title: "Unified IP Route Wrapper & Utilities"
# layer: "Functions"
# responsibility: "Wraps iproute2, provides public IP checking, and resolves local IP addresses"
# dependencies: ["curl", "jq", "ifconfig", "ip"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-09-23"
# tags: ["network", "utility"]
# ---

function ip --description "Network IP operations (local/public) with system fallback"
    if test (count $argv) -eq 0
        if command -sq ip
            command ip -c a
        else
            echo "ip: Command not found. Falling back to ifconfig..." >&2
            ifconfig
        end
        return
    end

    switch "$argv[1]"
        case public check
            if not command -sq curl
                echo "Error: 'curl' is required but not installed." >&2
                return 1
            end

            if not command -sq jq
                echo "Error: 'jq' is required but not installed." >&2
                return 1
            end

            set -l pubip (curl -sS --connect-timeout 3 --max-time 5 http://ifconfig.me/ip)
            if test $status -ne 0; or test -z "$pubip"
                echo "Error: Failed to retrieve public IP address." >&2
                return 1
            end

            set -l request (curl -sS --connect-timeout 3 --max-time 5 "http://ip-api.com/json/$pubip")
            if test $status -ne 0; or test -z "$request"
                echo "Error: Failed to retrieve geolocation data for IP $pubip." >&2
                return 1
            end

            set -l values (echo "$request" | command jq -r '.query, .city, .country, .isp')
            if test (count $values) -lt 4
                echo "Error: Failed to parse geolocation data." >&2
                return 1
            end

            set -l cur_ip $values[1]
            set -l city $values[2]
            set -l country $values[3]
            set -l isp $values[4]

            set -l bpurple (set_color --bold purple)
            set -l bgreen (set_color --bold green)
            set -l bblue (set_color --bold blue)
            set -l bred (set_color --bold red)
            set -l normal (set_color normal)

            printf "%sIP: %s%s %sCity: %s%s %sCountry: %s%s %sISP: %s%s\n" \
                "$bpurple" "$cur_ip" "$normal" \
                "$bgreen" "$city" "$normal" \
                "$bblue" "$country" "$normal" \
                "$bred" "$isp" "$normal"

        case local get
            set -l ips
            if type -q ip
                for interface in ppp0 eth0 tun0 wlan0 en0 en1
                    set -l if_ip (command ip -4 addr show dev $interface 2>/dev/null | string match -r 'inet (\d+\.\d+\.\d+\.\d+)')
                    if test -n "$if_ip"
                        set -l tokens (string match -ra '\S+' -- $if_ip[1])
                        set -a ips $tokens[2]
                    end
                end
            else if type -q ifconfig
                for interface in en0 en1 ppp0 tun0 utun0 utun1 utun2
                    set -l if_ip (ifconfig $interface 2>/dev/null | string match -r 'inet (\d+\.\d+\.\d+\.\d+)')
                    if test -n "$if_ip"
                        set -l tokens (string match -ra '\S+' -- $if_ip[1])
                        set -a ips $tokens[2]
                    end
                end
            end

            if test (count $ips) -gt 0
                printf "(%s)" (string join ", " $ips)
            end

        case '*'
            if command -sq ip
                command ip -c a $argv
            else
                ifconfig $argv
            end
    end
end
