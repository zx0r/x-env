# ---
# schema: "mdd-node-v1"
# id: "functions/y.fish"
# title: "Yazi Wrapper"
# layer: "Functions"
# responsibility: "Wrapper function for Yazi file manager to change cwd of shell on exit"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-06-25"
# last_commit: "f4adbd9652c78a01f562b7194602f3fa10eeea80"
# tags: ["navigation", "yazi"]
# ---

function y
    set tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set cwd (command cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
