# ---
# schema: "mdd-node-v1"
# id: "functions/backup.fish"
# title: "File Backup"
# layer: "Functions"
# responsibility: "Creates a backup copy of a specified file with .bak extension"
# dependencies: []
# backlinks: []
# created_at: "2026-06-24"
# updated_at: "2026-06-25"
# last_commit: "f4adbd9652c78a01f562b7194602f3fa10eeea80"
# tags: ["filesystem", "utility"]
# ---

# Make a backup file
function backup --argument filename
    cp $filename $filename.bak
end
