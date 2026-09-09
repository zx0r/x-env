# ---
# schema: "mdd-node-v1"
# id: "functions/diskcheck.fish"
# title: "macOS Disk Volume Status Inspector"
# layer: "Functions"
# responsibility: "Inspects macOS disk volume mount status, APFS container details, and capacity usage"
# dependencies: []
# backlinks: ["conf.d/20-abbr.fish"]
# created_at: "2026-09-10"
# updated_at: "2026-09-10"
# tags: ["disk", "storage", "macos", "inspection"]
# ---

function diskcheck --description "Inspect macOS disk volume status and usage"
    if not test (uname) = "Darwin"
        df -h /
        return
    end

    diskutil info /
    echo
    df -h / /System/Volumes/Data
end
