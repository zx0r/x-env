# ---
# schema: "mdd-node-v1"
# id: "functions/macos-security.fish"
# title: "macOS Defense-in-Depth & State Drift Controller CLI"
# layer: "Functions"
# responsibility: "Provides high-performance JIT shell integration for NIST SP 800-219 & CIS macOS security drift audits"
# dependencies: ["bin/macos-security"]
# backlinks: []
# created_at: "2026-10-21"
# updated_at: "2026-10-21"
# tags: ["security", "packet-filter", "defense-in-depth", "drift-engine", "zero-fork", "nist", "cis"]
# ---

function macos-security --description "NIST SP 800-219 & CIS macOS Defense-in-Depth State Drift Controller"
    set -l bin_path "$HOME/x/dev/own/macos-security/bin/macos-security"
    if not test -x "$bin_path"
        set bin_path "$HOME/.local/bin/macos-security"
    end

    if not test -x "$bin_path"
        echo (set_color red)"[ERROR] macos-security executable not found at: $bin_path"(set_color normal) >&2
        return 1
    end

    switch "$argv[1]"
        case log
            echo (set_color bold)"[Listening on pflog0 BPF interface (Ctrl+C to abort)]..."(set_color normal)
            sudo /usr/sbin/tcpdump -n -e -ttt -i pflog0
        case "*"
            if test (count $argv) -eq 0
                $bin_path --check
            else
                $bin_path $argv
            end
    end
end
