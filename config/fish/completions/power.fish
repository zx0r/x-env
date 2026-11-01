# Fish completions for power governor
complete -c power -f

complete -c power -n "__fish_use_subcommand" -a status -d "Display unified battery health, telemetry & profile card"
complete -c power -n "__fish_use_subcommand" -a audit -d "Audit DarkWake loops, TCP keepalive wakeups & sleep culprits"
complete -c power -n "__fish_use_subcommand" -a assertions -d "List processes preventing system/display sleep"
complete -c power -n "__fish_use_subcommand" -a apply -d "Apply canonical pmset power profiles"
complete -c power -n "__fish_use_subcommand" -a caffeinate -d "Keep system awake for duration, task PID, or wrapped command"
complete -c power -n "__fish_use_subcommand" -a help -d "Display power manual"

# Subcommand: apply
complete -c power -n "__fish_seen_subcommand_from apply profile" -a balanced -d "Workstation default (120Hz ProMotion, full clocks, zero backpack drain)"
complete -c power -n "__fish_seen_subcommand_from apply profile" -a power-saver -d "Maximum endurance (LowPowerMode on battery, 60Hz cap)"
complete -c power -n "__fish_seen_subcommand_from apply profile" -a performance -d "Heavy compute (sleep=0 on AC, full clocks on battery)"
complete -c power -n "__fish_seen_subcommand_from apply profile" -a factory -d "Restore Apple out-of-the-box system defaults"

# Canonical Aliases
complete -c power -n "__fish_seen_subcommand_from apply profile" -a eco -d "Alias for power-saver"
complete -c power -n "__fish_seen_subcommand_from apply profile" -a workstation -d "Alias for performance"
complete -c power -n "__fish_seen_subcommand_from apply profile" -a restore -d "Alias for factory"

# Subcommand: caffeinate
complete -c power -n "__fish_seen_subcommand_from caffeinate" -s d -l display -d "Prevent display from sleeping"
complete -c power -n "__fish_seen_subcommand_from caffeinate" -s s -l system -d "Prevent system from sleeping (AC only)"
complete -c power -n "__fish_seen_subcommand_from caffeinate" -s t -l time -d "Prevent sleep for specified seconds"
complete -c power -n "__fish_seen_subcommand_from caffeinate" -s w -l wait -d "Prevent sleep until process PID terminates"
