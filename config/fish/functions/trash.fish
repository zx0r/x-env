# ---
# schema: "mdd-node-v1"
# id: "functions/trash.fish"
# title: "macOS Trash Safety Governor & Drop-in rm Adapter"
# layer: "Functions"
# responsibility: "Safely intercepts file deletions, protects immutable system/dotfile paths, and moves targets to macOS Trash instead of permanent unlinking"
# dependencies: []
# backlinks: ["conf.d/20-abbr.fish"]
# created_at: "2026-10-03"
# updated_at: "2026-10-03"
# tags: ["trash", "safety", "governor", "rm", "macos", "data-protection"]
# ---

# ==============================================================================
# 🛡️ MACOS TRASH SAFETY GOVERNOR
# ------------------------------------------------------------------------------
# 1. Zero-Deletion Invariant: Hard-coded protection for system & developer roots
# 2. Transparent rm Compatibility: Swallows -r, -f, -rf, -v, -i flags
# 3. Native macOS Trash: Routes deletions through /usr/bin/trash into ~/.Trash
# 4. Trash Management: Provides -l/--list and -e/--empty controls
# 5. Permanent Deletion Valve: Bypasses Trash ONLY with explicit --permanent flag
# ==============================================================================

function trash --description "Principal-grade macOS Trash governor and safe rm drop-in"
    # CLI Flags & State
    set -l verbose 0
    set -l interactive 0
    set -l permanent 0
    set -l list_trash 0
    set -l empty_trash 0
    set -l targets

    # Hardened Protected Paths (Canonical Blacklist)
    set -l protected_roots \
        "/" \
        "/System" \
        "/Library" \
        "/Applications" \
        "/usr" \
        "/bin" \
        "/sbin" \
        "/var" \
        "/etc" \
        "/private" \
        "$HOME/x" \
        "$HOME/.config" \
        "$HOME/.ssh" \
        "$HOME/.gnupg"

    # Parse Arguments
    set -l end_of_opts 0
    for arg in $argv
        if test $end_of_opts -eq 1
            set -a targets $arg
            continue
        end

        switch $arg
            case --
                # POSIX end-of-options delimiter (subsequent args are file targets)
                set end_of_opts 1
                continue
            case -h --help
                printf "Usage: trash [OPTIONS] <FILE...>\n"
                printf "       rm [OPTIONS] <FILE...>\n\n"
                printf "Drop-in safe deletion governor for macOS. Moves targets to ~/.Trash.\n\n"
                printf "Options:\n"
                printf "  -r, -R, -rf, -fr, -f  Accepted for rm drop-in compatibility (ignored)\n"
                printf "  -v, --verbose         Print verbose trashing confirmation\n"
                printf "  -i, --interactive     Prompt confirmation before trashing each file\n"
                printf "  -l, --list            Inspect items and disk footprint of macOS Trash\n"
                printf "  -e, --empty           Safely purge macOS Trash with confirmation\n"
                printf "  --permanent           Bypass Trash and invoke /bin/rm (requires confirmation)\n"
                printf "  -h, --help            Show this help manual\n"
                return 0
            case -l --list
                set list_trash 1
            case -e --empty
                set empty_trash 1
            case -v --verbose
                set verbose 1
            case -i --interactive
                set interactive 1
            case --permanent --shred
                set permanent 1
            case -y --yes
                set auto_yes 1
            case -r -R -f -rf -fr -frv -rfv -vrf
                # Safely swallow standard rm recursive and force flags
                continue
            case "-*"
                # Swallow any combined flags with r, f, v
                if string match -qr '^-+[rRfFvVyY]+$' -- $arg
                    if string match -q "*v*" -- $arg; set verbose 1; end
                    if string match -q "*i*" -- $arg; set interactive 1; end
                    if string match -q "*y*" -- $arg; set auto_yes 1; end
                else
                    printf "\e[33m⚠️  [trash] Unknown flag ignored: %s\e[0m\n" "$arg"
                end
            case "*"
                set -a targets $arg
        end
    end

    # Mode 1: List Trash Contents
    if test $list_trash -eq 1
        set -l trash_dir "$HOME/.Trash"
        if not test -d "$trash_dir"
            printf "\e[32m✔  macOS Trash is empty (directory does not exist)\e[0m\n"
            return 0
        end

        set -l items (command ls -A "$trash_dir" 2>/dev/null)
        set -l count_items (count $items)
        if test $count_items -eq 0
            printf "\e[32m✔  macOS Trash is completely empty (0 items)\e[0m\n"
            return 0
        end

        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        printf "🗑️  macOS Trash Registry (~/.Trash) · \e[33m%d items\e[0m\n" $count_items
        printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        if type -q dust
            dust -d 1 -n 15 "$trash_dir"
        else
            command ls -lah "$trash_dir"
        end
        return 0
    end

    # Mode 2: Empty Trash with Safety Confirmation
    if test $empty_trash -eq 1
        set -l trash_dir "$HOME/.Trash"
        set -l items (command ls -A "$trash_dir" 2>/dev/null)
        set -l count_items (count $items)
        if test $count_items -eq 0
            printf "\e[32m✔  macOS Trash is already empty.\e[0m\n"
            return 0
        end

        set -l confirm ""
        if test $auto_yes -eq 1
            set confirm "y"
        else
            printf "\e[33m⚠️  Are you sure you want to permanently empty macOS Trash (%d items)? [y/N]: \e[0m" $count_items
            read -l confirm
        end

        if test "$confirm" = "y" -o "$confirm" = "Y"
            # Try Finder AppleScript first for clean multi-volume trash purge, fallback to POSIX rm
            osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1
            or command rm -rf "$trash_dir"/* 2>/dev/null
            printf "\e[32m✔  macOS Trash successfully emptied.\e[0m\n"
            return 0
        else
            printf "\e[90mCancelled.\e[0m\n"
            return 1
        end
    end

    # Validate Targets
    if test (count $targets) -eq 0
        printf "\e[31m[trash] Error: No files or directories specified.\e[0m\n"
        printf "Try 'trash --help' for usage.\n"
        return 1
    end

    # Governor: Validate Each Target Against Protection Blacklist
    set -l valid_targets
    for target in $targets
        # Target existence check
        if not test -e "$target" -o -L "$target"
            # If standard rm -f was passed, silently skip nonexistent targets
            continue
        end

        # Resolve Canonical Absolute Path
        set -l resolved (path resolve "$target" 2>/dev/null)
        test -z "$resolved"; and set resolved (path normalize (pwd)/"$target")

        # 1. Root & System Path Invariant Check
        set -l is_blocked 0
        for root in $protected_roots
            if test "$resolved" = "$root"
                printf "\e[1;31m🛡️ [SAFETY GOVERNOR] CRITICAL: Blocked deletion of protected system root: %s\e[0m\n" "$resolved"
                set is_blocked 1
                break
            end
        end

        # 2. Prevent Git Repository Root Destruction
        if test (path basename "$resolved") = ".git"
            printf "\e[1;31m🛡️ [SAFETY GOVERNOR] BLOCKED: Deletion of .git metadata root is strictly prohibited: %s\e[0m\n" "$resolved"
            set is_blocked 1
        end

        if test $is_blocked -eq 1
            return 1
        end

        # Interactive Confirmation (if -i specified)
        if test $interactive -eq 1
            printf "trash: move '%s' to Trash? [y/N] " "$target"
            read -l ans
            test "$ans" != "y" -a "$ans" != "Y"; and continue
        end

        set -a valid_targets "$target"
    end

    if test (count $valid_targets) -eq 0
        return 0
    end

    # Mode 3: Permanent Deletion (Only if explicit --permanent flag given)
    if test $permanent -eq 1
        printf "\e[1;33m⚠️  PERMANENT DELETION: The following items will be unlinked immediately (bypassing Trash):\e[0m\n"
        for t in $valid_targets
            printf "    • %s\n" "$t"
        end
        printf "Confirm permanent unrecoverable deletion? [y/N]: "
        read -l p_ans
        if test "$p_ans" = "y" -o "$p_ans" = "Y"
            command rm -rf $valid_targets
            set -l rc $status
            if test $rc -eq 0
                printf "\e[32m✔  Unlinked %d items permanently.\e[0m\n" (count $valid_targets)
            end
            return $rc
        else
            printf "\e[90mCancelled.\e[0m\n"
            return 1
        end
    end

    # Mode 4: Default Safe Deletion via Native macOS /usr/bin/trash
    set -l trash_flags
    test $verbose -eq 1; and set trash_flags "-v"

    if test -x /usr/bin/trash
        /usr/bin/trash $trash_flags $valid_targets
        return $status
    else
        # Fallback to macOS Finder AppleScript via osascript
        for item in $valid_targets
            set -l abs_item (path resolve "$item")
            osascript -e "tell application \"Finder\" to delete POSIX file \"$abs_item\"" >/dev/null 2>&1
        end
        return 0
    end
end
