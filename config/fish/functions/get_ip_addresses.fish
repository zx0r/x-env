# ---
# schema: "mdd-node-v1"
# id: "functions/get_ip_addresses.fish"
# title: "Local IP Resolver"
# layer: "Functions"
# responsibility: "Resolves active local IP addresses portably across macOS and Linux without piping external tools"
# dependencies: ["ifconfig", "ip"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "utility"]
# ---

function get_ip_addresses --description "Resolve active local IP addresses portably across macOS and Linux"
    set -l ips
    
    if type -q ip
        # Linux / iproute2 implementation
        for interface in ppp0 eth0 tun0 wlan0 en0 en1
            set -l ip (ip -4 addr show dev $interface 2>/dev/null | string match -r 'inet (\d+\.\d+\.\d+\.\d+)')
            if test -n "$ip"
                # Extract the IP address token (second element after 'inet')
                set -l tokens (string match -ra '\S+' -- $ip[1])
                set -a ips $tokens[2]
            end
        end
    else if type -q ifconfig
        # macOS / BSD implementation
        for interface in en0 en1 ppp0 tun0 utun0 utun1 utun2
            set -l ip (ifconfig $interface 2>/dev/null | string match -r 'inet (\d+\.\d+\.\d+\.\d+)')
            if test -n "$ip"
                # Extract the IP address token (second element after 'inet')
                set -l tokens (string match -ra '\S+' -- $ip[1])
                set -a ips $tokens[2]
            end
        end
    end

    if test (count $ips) -gt 0
        printf "(%s)" (string join ", " $ips)
    end
end
