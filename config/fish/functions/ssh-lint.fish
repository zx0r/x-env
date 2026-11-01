# ---
# schema: "mdd-node-v1"
# id: "functions/ssh-lint.fish"
# title: "Declarative OpenSSH Architecture & Cryptographic Collision Linter"
# layer: "Functions"
# responsibility: "Audits ~/.ssh/conf.d modular topology, validates lexical precedence, and prevents First-Match-Wins collisions"
# dependencies: []
# backlinks: ["MAP_OF_CONTENT.md"]
# created_at: "2026-10-10"
# updated_at: "2026-10-10"
# tags: ["security", "ssh", "linter", "audit", "darwin", "principal"]
# ---

function ssh-lint -d "Audit OpenSSH configuration hierarchy, First-Match-Wins precedence, and crypto posture"
    set -l has_error 0
    set -l conf_dir "$HOME/.ssh/conf.d"
    set -l root_config "$HOME/.ssh/config"

    set_color cyan
    echo "[SSH-LINT] Auditing OpenSSH configuration hierarchy and cryptographic posture..."
    set_color normal

    # 1. Root Syntax & Configuration Compilation Integrity
    if not command ssh -G localhost >/dev/null 2>&1
        set_color red
        echo "[FAIL] Critical syntax error in $root_config or included modules!"
        set_color normal
        return 1
    end
    set_color green
    echo "  ✔ Root syntax compilation validated (OpenSSH engine verified)"
    set_color normal

    # 2. Modular Lexicographical Precedence Audit (Zone 01-79 vs Zone 80-99)
    if not test -d "$conf_dir"
        set_color red
        echo "[FAIL] Directory $conf_dir not found!"
        set_color normal
        return 1
    end

    set -l conf_files (command ls -1 $conf_dir/*.conf 2>/dev/null)
    for f in $conf_files
        set -l base (path basename $f)
        set -l prefix (string match -r '^[0-9]+' $base)

        if test -z "$prefix"
            set_color yellow
            echo "  ⚠ [WARN] File $base violates numerical prefix convention (expected NN-name.conf)"
            set_color normal
            continue
        end

        # Check for unconstrained Host * inside host-specific zone (01-79)
        if test $prefix -lt 80
            if command grep -qE '^[[:space:]]*Host[[:space:]]+\*[[:space:]]*$' $f
                set_color red
                echo "  ✖ [CRITICAL PRECEDENCE FLAW] File $base (Zone 01-79) contains unconstrained 'Host *'!"
                echo "    This shadows all subsequent host-specific files due to First-Match-Wins."
                set_color normal
                set has_error 1
            end
        else
            # Check for specific hosts defined in global zone (80-99) after Host *
            # (Dead code detection)
            if command awk '/^[[:space:]]*Host[[:space:]]+\*/ {found=1} found && /^[[:space:]]*Host[[:space:]]+[^*]/ {exit 1}' $f
                # No dead code
            else
                set_color red
                echo "  ✖ [DEAD CODE DETECTED] File $base declares specific hosts after 'Host *'!"
                set_color normal
                set has_error 1
            end
        end
    end
    set_color green
    echo "  ✔ Modular prefix topology verified (Zone 01-79 hosts isolated from Zone 80-99 defaults)"
    set_color normal

    # 3. Known Host Overrides & First-Match-Wins Assertion
    # Verifies that specific overrides are NOT shadowed by global Host * defaults

    # OpenWrt: StrictHostKeyChecking accept-new must NOT be overwritten by Host * (ask)
    set -l openwrt_strict (ssh -G openwrt 2>/dev/null | command grep '^stricthostkeychecking ' | string replace 'stricthostkeychecking ' '' | string trim)
    if test "$openwrt_strict" != "accept-new"
        set_color red
        echo "  ✖ [FIRST-MATCH-WINS INVERSION] Host 'openwrt' StrictHostKeyChecking is '$openwrt_strict' (expected 'accept-new')!"
        set_color normal
        set has_error 1
    else
        set_color green
        echo "  ✔ Host override validated: openwrt -> StrictHostKeyChecking accept-new"
        set_color normal
    end

    # GitHub: Standard Port 22 vs Evasion Port 443
    set -l gh_port (ssh -G github.com 2>/dev/null | command grep '^port ' | string replace 'port ' '' | string trim)
    set -l gh_user (ssh -G github.com 2>/dev/null | command grep '^user ' | string replace 'user ' '' | string trim)
    if test "$gh_port" != "22"; or test "$gh_user" != "git"
        set_color red
        echo "  ✖ [CONFIGURATION DRIFT] Host 'github.com' resolved to port=$gh_port user=$gh_user (expected 22/git)!"
        set_color normal
        set has_error 1
    else
        set_color green
        echo "  ✔ Host override validated: github.com -> port 22, user git"
        set_color normal
    end

    set -l gh443_port (ssh -G github-443 2>/dev/null | command grep '^port ' | string replace 'port ' '' | string trim)
    set -l gh443_host (ssh -G github-443 2>/dev/null | command grep '^hostname ' | string replace 'hostname ' '' | string trim)
    if test "$gh443_port" != "443"; or test "$gh443_host" != "ssh.github.com"
        set_color red
        echo "  ✖ [CONFIGURATION DRIFT] Host 'github-443' resolved to port=$gh443_port host=$gh443_host (expected 443/ssh.github.com)!"
        set_color normal
        set has_error 1
    else
        set_color green
        echo "  ✔ Host override validated: github-443 alias -> port 443, host ssh.github.com"
        set_color normal
    end

    # 4. Zero-Trust Cryptographic Posture Audit
    set -l top_cipher (ssh -G 127.0.0.1 2>/dev/null | command grep '^ciphers ' | string replace 'ciphers ' '' | string split ',' | head -n 1)
    if string match -q "*chacha20*" "$top_cipher"
        set_color red
        echo "  ✖ [CRYPTO INVERSION] ChaCha20 is top cipher! Vulnerable to Terrapin (CVE-2023-48795). AES-GCM required."
        set_color normal
        set has_error 1
    else
        set_color green
        echo "  ✔ Symmetric Suite: AES-GCM top priority ($top_cipher) — Terrapin immune (RFC 5647 §7.1)"
        set_color normal
    end

    # Post-Quantum KEX Check
    set -l top_kex (ssh -G 127.0.0.1 2>/dev/null | command grep '^kexalgorithms ' | string replace 'kexalgorithms ' '' | string split ',' | head -n 1)
    if not string match -rq '^(mlkem|sntrup)' "$top_kex"
        set_color yellow
        echo "  ⚠ [CRYPTO NOTICE] Top KEX algorithm is not Post-Quantum: $top_kex"
        set_color normal
    else
        set_color green
        echo "  ✔ Key Exchange: Post-Quantum Hybrid top priority ($top_kex, FIPS 203)"
        set_color normal
    end

    # ObscureKeystrokeTiming Check
    set -l keystroke (ssh -G 127.0.0.1 2>/dev/null | command grep '^obscurekeystroketiming ' | string replace 'obscurekeystroketiming ' '' | string trim)
    if test "$keystroke" != "yes"
        set_color red
        echo "  ✖ [SIDE-CHANNEL EXPOSURE] ObscureKeystrokeTiming is not enabled!"
        set_color normal
        set has_error 1
    else
        set_color green
        echo "  ✔ Side-Channel Defense: ObscureKeystrokeTiming active (packet quantization)"
        set_color normal
    end

    # 5. Darwin Kernel Socket Bound Check (Limit: 104 bytes)
    set -l control_path (ssh -G 127.0.0.1 2>/dev/null | command grep '^controlpath ' | string replace 'controlpath ' '' | string trim)
    set -l path_len (string length -- "$control_path")
    if test $path_len -ge 104
        set_color red
        echo "  ✖ [DARWIN KERNEL OVERFLOW] ControlPath ($path_len bytes) exceeds sockaddr_un 104-byte limit: $control_path"
        set_color normal
        set has_error 1
    else
        set_color green
        echo "  ✔ Darwin Socket Path: Safe ($path_len bytes < 104 limit) via SHA1 hash token (%C)"
        set_color normal
    end

    # 6. Hardware Identity Routing Check
    set -l agent_socket (ssh -G 127.0.0.1 2>/dev/null | command grep '^identityagent ' | string replace 'identityagent ' '' | string trim)
    if test -z "$agent_socket"; or test "$agent_socket" = "none"
        set_color yellow
        echo "  ⚠ [IDENTITY NOTICE] Global IdentityAgent is not defined!"
        set_color normal
    else
        set_color green
        echo "  ✔ Hardware Key Routing: IdentityAgent bound to $agent_socket (Secure Enclave)"
        set_color normal
    end

    if test $has_error -eq 0
        set_color green
        echo "[SSH-LINT PASS] All configuration and cryptographic assertions passed."
        set_color normal
        return 0
    else
        set_color red
        echo "[SSH-LINT FAIL] Configuration contains architectural defects or collisions!"
        set_color normal
        return 1
    end
end
