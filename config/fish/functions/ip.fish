# ---
# schema: "mdd-node-v1"
# id: "functions/ip.fish"
# title: "IP Route Wrapper"
# layer: "Functions"
# responsibility: "Wraps the iproute2 ip command to default to colorized address output, or falls back to ifconfig on macOS"
# dependencies: ["ip", "ifconfig"]
# backlinks: []
# created_at: "2026-06-25"
# updated_at: "2026-06-25"
# last_commit: ""
# tags: ["network", "utility"]
# ---

function ip --description "Wrap ip command with colorized address output"
    if command -sq ip
        command ip -c a $argv
    else
        echo "ip: Command not found. Falling back to ifconfig..." >&2
        ifconfig $argv
    end
end

