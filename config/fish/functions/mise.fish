# ---
# schema: "mdd-node-v1"
# id: "functions/mise.fish"
# title: "Static Mise Wrapper"
# layer: "Infrastructure (10-19)"
# responsibility: "Wraps the mise binary to handle shell-local commands (shell, deactivate) without shell-start overhead"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# last_commit: "pending"
# tags: ["mise", "wrapper", "performance"]
# ---

function mise --description "Static wrapper for mise-en-place runtime manager"
  if test (count $argv) -eq 0
    command /opt/homebrew/bin/mise
    return
  end

  set -l command $argv[1]
  set -e argv[1]

  if contains -- --help $argv
    command /opt/homebrew/bin/mise "$command" $argv
    return $status
  end

  switch "$command"
  case deactivate shell sh
    # if help is requested, don't eval
    if contains -- -h $argv
      command /opt/homebrew/bin/mise "$command" $argv
    else if contains -- --help $argv
      command /opt/homebrew/bin/mise "$command" $argv
    else
      source (command /opt/homebrew/bin/mise "$command" $argv |psub)
    end
  case '*'
    command /opt/homebrew/bin/mise "$command" $argv
  end
end
