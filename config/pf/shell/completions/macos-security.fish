# ---
# schema: "mdd-node-v1"
# id: "completions/macos-security.fish"
# title: "Completions for macos-security State Drift Controller"
# layer: "Completions"
# responsibility: "Context-aware autocompletion for NIST mSCP arguments and subsystem delegates"
# dependencies: ["functions/macos-security.fish"]
# backlinks: []
# created_at: "2026-10-21"
# updated_at: "2026-10-21"
# tags: ["completions", "security", "nist", "cis"]
# ---

complete -c macos-security -f

# Standard NIST mSCP Arguments
complete -c macos-security -s c -l check -d "Run compliance checks without interaction (audit mode)"
complete -c macos-security -s f -l fix -d "Apply remediation (with sudo) or inspect plan (without sudo)"
complete -c macos-security -l cfc -d "Runs Check -> Fix -> Check verification loop"
complete -c macos-security -l stats -d "Display compliance metrics and statistics"
complete -c macos-security -l json -d "Output results in machine-readable JSON format"
complete -c macos-security -s q -l quiet -d "Quiet mode (1 = failed only, 2 = minimal score)"
complete -c macos-security -l domain -x -a "perimeter kernel integrity persistence" -d "Isolate check to specific security domain"
complete -c macos-security -l tier -x -a "1 2 2.5 3 4" -d "Isolate check to specific defense tier"

# Subsystem Direct Delegation
complete -c macos-security -l pf -d "Invoke Packet Filter & ALF subsystem"
complete -c macos-security -l firewall -d "Invoke Packet Filter & ALF subsystem"
complete -c macos-security -l status -d "Detailed runtime subsystem status inspection"
complete -c macos-security -l sysctl -d "Invoke Kernel Network MIB subsystem"
complete -c macos-security -l integrity -d "Invoke Host Integrity subsystem"
complete -c macos-security -l launchd -d "Invoke LaunchDaemons subsystem"
complete -c macos-security -l validate -d "Invoke syntax and AST linter module"
complete -c macos-security -l tables -d "Dump active PF tables"
complete -c macos-security -l expire -d "Expire brute-force table entries older than N seconds"

# Logging action
complete -c macos-security -a "log" -d "Monitor live traffic on pflog0 BPF interface"
