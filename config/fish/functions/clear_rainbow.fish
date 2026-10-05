# ---
# schema: "mdd-node-v1"
# id: "functions/clear_rainbow.fish"
# title: "Rainbow Clear Utility"
# layer: "Functions"
# responsibility: "Provides an optional decorative rainbow screen clearing effect when explicitly invoked"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-10-04"
# tags: ["ux", "visual", "clear"]
# ---

function clear_rainbow --description "Decorative rainbow screen clearing effect"
    printf "\x1b[2J\x1b[1;1H"
    if type -q spark; and type -q lolcat
        seq 1 (tput cols) | sort -R | spark | lolcat
    end
end
