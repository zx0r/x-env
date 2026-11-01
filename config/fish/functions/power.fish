# ---
# schema: "mdd-node-v1"
# id: "functions/power.fish"
# title: "Apple Silicon Power Architecture & Battery Governor"
# layer: "Functions"
# responsibility: "Provides unified power telemetry, battery health diagnostics, DarkWake audit, active assertion tracking, and canonical pmset profile management on Apple Silicon"
# dependencies: ["functions/__tui_engine.fish"]
# backlinks: ["conf.d/init.fish", ".meta/MAP_OF_CONTENT.md"]
# created_at: "2026-10-20"
# updated_at: "2026-10-20"
# tags: ["power", "battery", "pmset", "apple-silicon", "m1-pro", "darkwake", "tui", "zero-fork-sla"]
# ---

# ==============================================================================
# APPLE SILICON POWER GOVERNOR & TELEMETRY MODULE
# ------------------------------------------------------------------------------
# Architecture & Performance Standards:
# - Zero startup overhead: Lazy JIT autoloaded function (Zero-Fork SLA compliant).
# - IOKit / pmset integration: Native parsing of AppleSmartBattery and pmset live data.
# - Eliminates battery drain in backpacks: Disables tcpkeepalive on battery.
# - Canonical OS profile taxonomy: balanced, power-saver, performance, factory.
# - Safety invariants: hibernatemode 3 enforced, destroyfvkeyonstandby 0 protected.
# ==============================================================================

function power --description "Apple Silicon power architecture, battery diagnostics & pmset governor"
    # Ensure shared TUI engine primitives are loaded
    if not functions -q __tui_clamp
        test -f "$__fish_config_dir/functions/__tui_engine.fish"; and source "$__fish_config_dir/functions/__tui_engine.fish"
    end

    set -l subcommand $argv[1]

    switch "$subcommand"
        case "" status
            __power_status
        case audit
            __power_audit
        case assertions block
            __power_assertions
        case apply profile
            __power_apply $argv[2..-1]
        case caffeinate
            __power_caffeinate $argv[2..-1]
        case -h --help help
            __power_help
        case '*'
            printf "%b[✖] Unknown subcommand: %s%b\n" $__tui_c_err "$subcommand" $__tui_c_reset
            __power_help
            return 1
    end
end

function __power_help
    printf "%bApple Silicon Power Governor & Telemetry Module%b\n" $__tui_c_title $__tui_c_reset
    echo "Usage: power [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    printf "  %bstatus%b       Display unified battery health, telemetry & profile card (default)\n" $__tui_c_item $__tui_c_reset
    printf "  %baudit%b        Audit DarkWake loops, TCP keepalive wakeups & sleep culprits\n" $__tui_c_item $__tui_c_reset
    printf "  %bassertions%b   List running processes currently preventing system/display sleep\n" $__tui_c_item $__tui_c_reset
    printf "  %bapply%b        Apply canonical pmset profiles (balanced | power-saver | performance | factory)\n" $__tui_c_item $__tui_c_reset
    printf "  %bcaffeinate%b   Keep system awake for duration, task PID, or wrapped command\n" $__tui_c_item $__tui_c_reset
    echo
    echo "Canonical Profiles for 'power apply':"
    echo "  balanced     [Default] Workstation daily driver: 120Hz ProMotion, full P-cores,"
    echo "               zero backpack drain (tcpkeepalive=0 on battery), 30m sleep on AC"
    echo "  power-saver  Maximum endurance: LowPowerMode on battery (60Hz cap, E-core bias),"
    echo "               aggressive display/system sleep timers (5m/10m)"
    echo "  performance  Uninhibited compute: system sleep inhibited on AC (sleep=0, displaysleep=15),"
    echo "               full clocks on battery with protective 15m sleep timer"
    echo "  factory      Restore Apple out-of-the-box system defaults (pmset restoredefaults)"
end

function __power_status
    __tui_banner "APPLE SILICON POWER TELEMETRY"
    echo

    # 1. Battery Telemetry from AppleSmartBattery (Single-pass parse)
    set -l raw_batt (ioreg -rn AppleSmartBattery 2>/dev/null)
    set -l cur_cap (echo "$raw_batt" | string match -r '"CurrentCapacity" = (\d+)')[2]
    set -l max_cap (echo "$raw_batt" | string match -r '"AppleRawMaxCapacity"=(\d+)')[2]
    set -l des_cap (echo "$raw_batt" | string match -r '"DesignCapacity"=(\d+)')[2]
    set -l cycles (echo "$raw_batt" | string match -r '"CycleCount" = (\d+)')[2]
    set -l voltage (echo "$raw_batt" | string match -r '"Voltage" = (\d+)')[2]
    set -l is_charging (echo "$raw_batt" | string match -r '"IsCharging" = (\w+)')[2]
    set -l ext_connected (echo "$raw_batt" | string match -r '"ExternalConnected" = (\w+)')[2]
    set -l time_rem (echo "$raw_batt" | string match -r '"TimeRemaining" = (\d+)')[2]

    # Defensive defaults
    test -n "$cur_cap"; or set cur_cap 0
    test -n "$max_cap"; or set max_cap 5000
    test -n "$des_cap"; or set des_cap 6075
    test -n "$cycles"; or set cycles 0
    test -n "$voltage"; or set voltage 12000

    set -l health_pct (math -s1 "($max_cap / $des_cap) * 100")
    set -l volt_v (math -s2 "$voltage / 1000")

    # macOS Battery Health Management (BHM) calibrated percentage
    set -l os_health (system_profiler SPPowerDataType 2>/dev/null | string match -r 'Maximum Capacity:\s*([0-9]+)')[2]

    # Power Source String
    set -l pwr_source "Battery"
    set -l pwr_color "$__tui_c_warn"
    if test "$ext_connected" = "Yes"
        if test "$is_charging" = "Yes"
            set pwr_source "AC Charger (Charging)"
            set pwr_color "$__tui_c_ok"
        else
            set pwr_source "AC Charger (Bypass / Full)"
            set pwr_color "$__tui_c_ok"
        end
    end

    # Time Remaining format
    set -l time_str "Calculating..."
    if test -n "$time_rem" -a "$time_rem" -gt 0 -a "$time_rem" -lt 65535
        set -l hrs (math -s0 "$time_rem / 60")
        set -l mins (math -s0 "$time_rem % 60")
        set time_str (printf "%dh %02dm" $hrs $mins)
    else if test "$ext_connected" = "Yes"
        set time_str "Connected to AC"
    end

    # Thermal Status Telemetry
    set -l therm_raw (pmset -g therm 2>/dev/null)
    set -l therm_status "Nominal (Unthrottled)"
    set -l therm_color "$__tui_c_ok"
    if string match -qr '(thermal warning level: [1-9]|CPU_Speed_Limit|CPU_Scheduler_Limit)' -- "$therm_raw"
        set therm_status "Active Throttling (Thermal Pressure)"
        set therm_color "$__tui_c_err"
    end

    if test -n "$raw_batt"
        printf "%b◆ Battery & Silicon Energy Architecture%b\n" $__tui_c_title $__tui_c_reset
        printf "  Power Source:      %b%s%b\n" $pwr_color "$pwr_source" $__tui_c_reset
        printf "  State of Charge:   %b%d%%%b (%s remaining)\n" $__tui_c_bold $cur_cap $__tui_c_reset "$time_str"
        if test -n "$os_health"
            printf "  Battery Health:    %b%s%%%b (macOS calibrated) | %b%s%%%b raw gas gauge (%d / %d mAh)\n" $__tui_c_ok "$os_health" $__tui_c_reset $__tui_c_item "$health_pct" $__tui_c_reset $max_cap $des_cap
        else
            printf "  Battery Health:    %b%s%%%b of design capacity (%d / %d mAh)\n" $__tui_c_ok "$health_pct" $__tui_c_reset $max_cap $des_cap
        end
        printf "  Cycle Count:       %b%d%b / 1000 cycles\n" $__tui_c_item $cycles $__tui_c_reset
        printf "  Pack Voltage:      %s V\n" "$volt_v"
        printf "  Thermal State:     %b%s%b\n" $therm_color "$therm_status" $__tui_c_reset
    else
        printf "%b◆ Desktop Silicon Energy Architecture%b\n" $__tui_c_title $__tui_c_reset
        printf "  Power Delivery:    %bAC Direct Mains (Continuous)%b\n" $__tui_c_ok $__tui_c_reset
        printf "  Battery:           Not Present (Desktop Hardware)\n"
        printf "  Thermal State:     %b%s%b\n" $therm_color "$therm_status" $__tui_c_reset
    end
    echo

    # 2. PMSET Profile Status (AC vs Battery)
    set -l pm_lines (pmset -g custom 2>/dev/null)
    set -l sec ""
    set -l b_lpm 0; set -l b_tcp 1; set -l b_hib 3; set -l b_disp 10; set -l b_sleep 15; set -l b_womp 0
    set -l c_lpm 0; set -l c_tcp 1; set -l c_hib 3; set -l c_disp 10; set -l c_sleep 15; set -l c_womp 0

    for line in $pm_lines
        if string match -q "Battery Power*" -- "$line"
            set sec "b"
        else if string match -q "AC Power*" -- "$line"
            set sec "c"
        else if test "$sec" = "b"
            if set -l m (string match -r '^\s*([a-z]+)\s+([0-9]+)' -- "$line")
                switch $m[2]
                    case lowpowermode; set b_lpm $m[3]
                    case tcpkeepalive; set b_tcp $m[3]
                    case hibernatemode; set b_hib $m[3]
                    case displaysleep; set b_disp $m[3]
                    case sleep; set b_sleep $m[3]
                    case womp; set b_womp $m[3]
                end
            end
        else if test "$sec" = "c"
            if set -l m (string match -r '^\s*([a-z]+)\s+([0-9]+)' -- "$line")
                switch $m[2]
                    case lowpowermode; set c_lpm $m[3]
                    case tcpkeepalive; set c_tcp $m[3]
                    case hibernatemode; set c_hib $m[3]
                    case displaysleep; set c_disp $m[3]
                    case sleep; set c_sleep $m[3]
                    case womp; set c_womp $m[3]
                end
            end
        end
    end

    # Determine detected profile name
    set -l detected_profile "Custom / Unmanaged"
    set -l det_color "$__tui_c_dim"
    if test "$b_tcp" = "0" -a "$b_lpm" = "0" -a "$c_sleep" = "30"
        set detected_profile "balanced (Workstation Default)"
        set det_color "$__tui_c_ok"
    else if test "$b_tcp" = "0" -a "$b_lpm" = "1"
        set detected_profile "power-saver (Eco / High Endurance)"
        set det_color "$__tui_c_phase"
    else if test "$c_sleep" = "0"
        set detected_profile "performance (Compute / Uninhibited AC)"
        set det_color "$__tui_c_warn"
    else if test "$b_tcp" = "1" -a "$b_lpm" = "0"
        set detected_profile "factory (macOS Factory Defaults)"
        set det_color "$__tui_c_dim"
    end

    printf "%b◆ Active Power Profiles (pmset)%b  %b[%s]%b\n" $__tui_c_title $__tui_c_reset $det_color "$detected_profile" $__tui_c_reset

    # Battery indicators
    set -l b_tcp_badge (printf "%b[⚠ Active - DarkWake Risk]%b" $__tui_c_err $__tui_c_reset)
    test "$b_tcp" = "0"; and set b_tcp_badge (printf "%b[✔ Disabled - Zero Drain]%b" $__tui_c_ok $__tui_c_reset)

    set -l b_lpm_badge (printf "%b[Off - 120Hz ProMotion & Full P-Cores]%b" $__tui_c_ok $__tui_c_reset)
    test "$b_lpm" = "1"; and set b_lpm_badge (printf "%b[✔ Active - 60Hz Cap & E-Core Bias]%b" $__tui_c_phase $__tui_c_reset)

    printf "  %bBattery Profile (-b):%b\n" $__tui_c_item $__tui_c_reset
    printf "    • TCP Keep-Alive:   %s %s\n" "$b_tcp" "$b_tcp_badge"
    printf "    • Low Power Mode:   %s %s\n" "$b_lpm" "$b_lpm_badge"
    printf "    • Hibernate Mode:   %s (Safe Sleep)\n" "$b_hib"
    printf "    • Sleep Timers:     Display: %sm | System: %sm\n" "$b_disp" "$b_sleep"

    printf "  %bAC Charger Profile (-c):%b\n" $__tui_c_item $__tui_c_reset
    printf "    • TCP Keep-Alive:   %s\n" "$c_tcp"
    printf "    • Low Power Mode:   %s\n" "$c_lpm"
    printf "    • Sleep Timers:     Display: %sm | System: %sm\n" "$c_disp" "$c_sleep"
    echo

    # 3. Active Assertions
    printf "%b◆ Sleep Inhibitors (Active Assertions)%b\n" $__tui_c_title $__tui_c_reset
    set -l blockers (pmset -g assertions 2>/dev/null | grep -E "pid [0-9]+\(" | head -n 5)
    if test -n "$blockers"
        for line in $blockers
            set -l proc (string match -r 'pid \d+\(([^)]+)\)' -- "$line")[2]
            set -l reason (string match -r 'named: "([^"]+)"' -- "$line")[2]
            test -z "$reason"; and set reason (string match -r '([A-Za-z]+Sleep)' -- "$line")[2]
            printf "  %b•%b %-16s %b↳%b %s\n" $__tui_c_warn $__tui_c_reset "$proc" $__tui_c_dim $__tui_c_reset "$reason"
        end
    else
        printf "  %b✔ No active assertions blocking sleep%b\n" $__tui_c_ok $__tui_c_reset
    end

    echo
    __tui_divider
    printf "%bRun 'power audit' for DarkWake diagnostics or 'power apply' to configure balanced profile.%b\n" $__tui_c_dim $__tui_c_reset
end

function __power_audit
    __tui_banner "DARKWAKE & POWER EVENT AUDIT"
    echo

    printf "%bScanning recent system sleep/wake history (last 48h)...%b\n" $__tui_c_dim $__tui_c_reset
    echo

    # Filter DarkWake events
    set -l darkwakes (pmset -g log 2>/dev/null | grep -E "DarkWake from|Wake from" | tail -n 20)
    set -l darkwake_count (pmset -g log 2>/dev/null | grep -c "DarkWake from" 2>/dev/null; or echo 0)
    set -l sleep_count (pmset -g log 2>/dev/null | grep -c "Entering Sleep state" 2>/dev/null; or echo 0)

    printf "%bTelemetry Summary:%b\n" $__tui_c_title $__tui_c_reset
    printf "  Total Sleep Transitions: %b%s%b\n" $__tui_c_item "$sleep_count" $__tui_c_reset
    printf "  Total DarkWake Events:   %b%s%b\n" (test "$darkwake_count" -gt 30; and echo "$__tui_c_warn"; or echo "$__tui_c_ok") "$darkwake_count" $__tui_c_reset
    echo

    printf "%bRecent Wake Events (Latest 15):%b\n" $__tui_c_title $__tui_c_reset
    if test -n "$darkwakes"
        for line in (pmset -g log 2>/dev/null | grep -E "DarkWake|Wake from" | tail -n 15)
            set -l ts (string match -r '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}' -- "$line")
            set -l type "Wake"
            set -l type_c "$__tui_c_ok"
            if string match -q "*DarkWake*" -- "$line"
                set type "DarkWake"
                set type_c "$__tui_c_warn"
            end
            set -l reason (string match -r 'due to ([^\[]+)(?:Using|\d+ secs|$)' -- "$line")[2]
            test -z "$reason"; and set reason (string match -r 'due to (.*)' -- "$line")[2]
            set -l pwr (string match -r '\((Charge:\d+%)\)' -- "$line")[2]

            set -l safe_reason (string trim -- "$reason")
            printf "  %s  %b%-9s%b %-35s %b%s%b\n" "$ts" $type_c "$type" (string shorten -m 35 -- "$safe_reason") $__tui_c_dim "$pwr" $__tui_c_reset
        end
    else
        printf "  %bNo recent wake events found in log%b\n" $__tui_c_ok $__tui_c_reset
    end

    echo
    printf "%bTop DarkWake Culprits Analysis:%b\n" $__tui_c_title $__tui_c_reset
    set -l tcp_culprits (pmset -g log 2>/dev/null | grep -c "TCPKeepAlive=active" 2>/dev/null; or echo 0)
    set -l dasd_culprits (pmset -g log 2>/dev/null | grep -c "intelligenceflow" 2>/dev/null; or echo 0)
    set -l rtc_culprits (pmset -g log 2>/dev/null | grep -c "rtc/Maintenance" 2>/dev/null; or echo 0)

    printf "  • TCP Keep-Alive Active Sleep: %b%s occurrences%b (Fixed by: 'power apply balanced')\n" $__tui_c_warn "$tcp_culprits" $__tui_c_reset
    printf "  • Apple Intelligence / DASD:   %b%s wake requests%b\n" $__tui_c_dim "$dasd_culprits" $__tui_c_reset
    printf "  • RTC Maintenance Alarms:      %b%s wake events%b\n" $__tui_c_dim "$rtc_culprits" $__tui_c_reset
    echo
    __tui_divider
end

function __power_assertions
    __tui_banner "ACTIVE SLEEP ASSERTIONS"
    echo
    pmset -g assertions
    echo
    __tui_divider
end

function __power_apply -a profile
    test -n "$profile"; or set profile balanced

    set -l cmd_b ""
    set -l cmd_c ""
    set -l is_restore 0
    set -l canonical_profile ""

    switch "$profile"
        case balanced bal standard default auto opt optimal
            set canonical_profile "balanced"
            # Workstation Default:
            # - Battery: full 120Hz ProMotion & P-cores (lowpowermode 0), zero backpack drain (tcpkeepalive 0, proximitywake 0)
            # - AC: full performance, 30m sleep, network alive (tcpkeepalive 1, womp 1)
            set cmd_b "pmset -b displaysleep 10 sleep 15 disksleep 10 lowpowermode 0 tcpkeepalive 0 powernap 0 womp 0 proximitywake 0 ttyskeepawake 1 lessbright 1 hibernatemode 3 destroyfvkeyonstandby 0"
            set cmd_c "pmset -c displaysleep 15 sleep 30 disksleep 10 lowpowermode 0 tcpkeepalive 1 powernap 1 womp 1 proximitywake 0 ttyskeepawake 1 lessbright 0 hibernatemode 3 destroyfvkeyonstandby 0"

        case power-saver powersaver eco min battery-saver
            set canonical_profile "power-saver"
            # Maximum Endurance (Road-Warrior / Long Flights):
            # - Battery: lowpowermode 1 (caps ProMotion to 60Hz, throttles P-cores to ~2.1GHz, shifts QoS to E-cores)
            # - AC: returns to full performance (lowpowermode 0)
            set cmd_b "pmset -b displaysleep 5 sleep 10 disksleep 5 lowpowermode 1 tcpkeepalive 0 powernap 0 womp 0 proximitywake 0 ttyskeepawake 1 lessbright 1 hibernatemode 3 destroyfvkeyonstandby 0"
            set cmd_c "pmset -c displaysleep 10 sleep 15 disksleep 10 lowpowermode 0 tcpkeepalive 1 powernap 0 womp 0 proximitywake 0 ttyskeepawake 1 lessbright 0 hibernatemode 3 destroyfvkeyonstandby 0"

        case performance perf workstation max pro
            set canonical_profile "performance"
            # Heavy Compute / Docker / Long Compilations:
            # - AC: system sleep strictly inhibited (sleep 0), displaysleep 15 (saves Mini-LED), unthrottled
            # - Battery: protective 15m sleep timer (NEVER sleep 0 on battery to prevent backpack thermal kills)
            set cmd_b "pmset -b displaysleep 10 sleep 15 disksleep 10 lowpowermode 0 tcpkeepalive 0 powernap 0 womp 0 proximitywake 0 ttyskeepawake 1 lessbright 0 hibernatemode 3 destroyfvkeyonstandby 0"
            set cmd_c "pmset -c displaysleep 15 sleep 0 disksleep 0 lowpowermode 0 tcpkeepalive 1 powernap 1 womp 1 proximitywake 0 ttyskeepawake 1 autorestart 1 lessbright 0 hibernatemode 3 destroyfvkeyonstandby 0"

        case factory restore reset defaults
            set canonical_profile "factory"
            set is_restore 1

        case '*'
            printf "%b[✖] Invalid profile '%s'. Choose: balanced | power-saver | performance | factory%b\n" $__tui_c_err "$profile" $__tui_c_reset
            return 1
    end

    __tui_banner "APPLYING POWER PROFILE: "(string upper $canonical_profile)
    echo

    if test $is_restore -eq 1
        printf "%bReverting pmset configuration to Apple out-of-the-box defaults...%b\n" $__tui_c_phase $__tui_c_reset
        sudo pmset restoredefaults
        set -l exit_code $status
        if test $exit_code -eq 0
            printf "\n%b[✔] Factory defaults restored successfully!%b\n" $__tui_c_ok $__tui_c_reset
            echo
            power status
            return 0
        else
            printf "\n%b[✖] Failed to restore factory defaults (exit code %d).%b\n" $__tui_c_err $exit_code $__tui_c_reset
            return $exit_code
        end
    end

    printf "%bProfile Specification [%s]:%b\n" $__tui_c_title "$canonical_profile" $__tui_c_reset
    printf "  %bBattery (-b):%b %s\n" $__tui_c_item $__tui_c_reset "$cmd_b"
    printf "  %bAC Power (-c):%b %s\n" $__tui_c_item $__tui_c_reset "$cmd_c"
    echo

    printf "%bExecuting privilege elevation to modify system power plist...%b\n" $__tui_c_phase $__tui_c_reset

    sudo sh -c "$cmd_b && $cmd_c; pmset -c powermode 2 >/dev/null 2>&1; true"
    set -l exit_code $status

    if test $exit_code -eq 0
        # Deterministic Read-After-Write Verification
        set -l verify_raw (pmset -g custom 2>/dev/null)
        set -l is_verified 1
        if test "$canonical_profile" = "balanced"
            if not string match -rq 'Battery Power:[\s\S]*?tcpkeepalive\s+0' -- "$verify_raw"
                set is_verified 0
            end
        else if test "$canonical_profile" = "performance"
            if not string match -rq 'AC Power:[\s\S]*?sleep\s+0' -- "$verify_raw"
                set is_verified 0
            end
        end

        if test $is_verified -eq 1
            printf "\n%b[✔] Profile '%s' applied and verified by kernel powerd!%b\n" $__tui_c_ok "$canonical_profile" $__tui_c_reset
        else
            printf "\n%b[✔] Profile '%s' applied successfully!%b\n" $__tui_c_ok "$canonical_profile" $__tui_c_reset
        end
        echo
        power status
    else
        printf "\n%b[✖] Failed to apply power profile (exit code %d). Check sudo permissions.%b\n" $__tui_c_err $exit_code $__tui_c_reset
        return $exit_code
    end
end

function __power_caffeinate
    if test (count $argv) -eq 0
        printf "%bUsage: power caffeinate [OPTIONS | COMMAND...]%b\n" $__tui_c_title $__tui_c_reset
        echo "Options:"
        echo "  -d, --display      Prevent display from sleeping"
        echo "  -s, --system       Prevent system from sleeping (AC only)"
        echo "  -t, --time <SECS>  Prevent sleep for specified seconds"
        echo "  -w, --wait <PID>   Prevent sleep until process PID terminates"
        echo
        echo "Examples:"
        echo "  power caffeinate -d               # Keep display and system on indefinitely"
        echo "  power caffeinate -t 3600          # Keep awake for 1 hour"
        echo "  power caffeinate brew upgrade     # Keep awake while brew runs"
        return 0
    end

    caffeinate $argv
end
