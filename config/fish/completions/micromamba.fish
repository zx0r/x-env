# ---
# schema: "mdd-node-v1"
# id: "completions/micromamba.fish"
# title: "Micromamba Shell Completions"
# layer: "Completions"
# responsibility: "Defines micromamba subcommands, options, and dynamic environment completion logic for tab completion"
# dependencies: []
# backlinks: []
# created_at: "2026-07-12"
# updated_at: "2026-07-12"
# tags: ["micromamba", "conda", "completions", "performance"]
# ---

function __fish_mamba_envs
    micromamba env list | tail -n +3 | cut -d' ' -f3
end

function __fish_mamba_packages
    micromamba list | awk 'NR > 3 {print $1}'
end

function __fish_mamba_universal_optspecs
    string join \n 'h/help' 'a-version' 'b-rc-file=+' \
                   'c-no-rc' 'd-no-env' 'v/verbose' \
                   'o/-log-level=+' 'q/quiet' 'y/yes' \
                   'e-json' 'f-offline' \
                   'g-dry-run' 'i-experimental' 'r/root-prefix=+' \
                   'p/prefix=+' 'n/name=+'
end

function __fish_mamba_has_command
    set -l want_prefix $argv
    set -l argv (commandline -opc)
    set -e argv[1]
    argparse -i (__fish_mamba_universal_optspecs) -- $argv 2>/dev/null; or return 1
    set -l argv (string replace -r -- " ?-[^ ]+" "" "$argv")
    set -l argv (string replace -r "\s+" " " "$argv")
    test "$want_prefix" = "$argv"
end

function __fish_mamba_complete_subcmds
    for line in (string split \n (string trim $argv[2]))
        set tmp (string replace -r '\s{4,}+' ___ (string trim $line))
        set cmd (string split ___  $tmp -f 1)
        set description (string split ___ $tmp -f 2)
        if test -z $description
            complete -x -c micromamba -n $argv[1] -a $cmd
            complete -x -c mamba -n $argv[1] -a $cmd
        else
            complete -x -c micromamba -n $argv[1] -a $cmd -d $description
            complete -x -c mamba -n $argv[1] -a $cmd -d $description
        end
    end
end

function __fish_mamba_needs_env
    set -l cmd (commandline -opc)
    test $cmd[-1] = "-n"
end

# Top level commands
__fish_mamba_complete_subcmds '__fish_mamba_has_command' '
  shell                       Generate shell init scripts
  create                      Create new environment
  install                     Install packages in active environment
  update                      Update packages in active environment
  self-update                 Update micromamba
  repoquery                   Find and analyze packages in active environment or channels
  remove                      Remove packages from active environment
  list                        List packages in active environment
  package                     Extract a package or bundle files into an archive
  clean                       Clean package cache
  config                      Configuration of micromamba
  info                        Information about micromamba
  constructor                 Commands to support using micromamba in constructor
  env                         See `mamba/micromamba env --help`
  activate                    Activate an environment
  run                         Run an executable in an environment
  ps                          Show, inspect or kill running processes
  auth                        Login or logout of a given host
  search                      Find packages in active environment or channels

  deactivate                  Deactivate the current environment
'

# env subcommand
__fish_mamba_complete_subcmds '__fish_mamba_has_command env' '
  list                        List known environments
  export                      Export environment
  remove                      Remove an environment
'

# config subcommand
__fish_mamba_complete_subcmds '__fish_mamba_has_command config' '
  list                        List configuration values
  sources                     Show configuration sources
  describe                    Describe given configuration parameters
  prepend                     Add one configuration value to the beginning of a list key
  append                      Add one configuration value to the end of a list key
  remove-key                  Remove a configuration key and its values
  remove                      Remove a configuration value from a list key. This removes all instances of the value.
  set                         Set a configuration value
  get                         Get a configuration value
'

# repoquery
__fish_mamba_complete_subcmds '__fish_mamba_has_command repoquery' '
  search
  depends
  whoneeds
'

# shell
__fish_mamba_complete_subcmds '__fish_mamba_has_command shell' '
  init                        Add initialization in script to rc files
  deinit                      Remove activation script from rc files
  reinit                      Restore activation script from rc files
  hook                        Micromamba hook scripts
  activate                    Output activation code for the given shell
  reactivate                  Output reactivation code for the given shell
  deactivate                  Output deactivation code for the given shell
  enable_long_path_support    Output deactivation code for the given shell
'

# Commands that need environment as parameter
complete -x -c micromamba -n '__fish_mamba_has_command activate' -a '(__fish_mamba_envs)'
complete -x -c micromamba -n '__fish_mamba_has_command shell activate' -a '(__fish_mamba_envs)'
complete -x -c mamba -n '__fish_mamba_has_command activate' -a '(__fish_mamba_envs)'
complete -x -c mamba -n '__fish_mamba_has_command shell activate' -a '(__fish_mamba_envs)'

# Commands that need package as parameter
complete -x -c micromamba -n '__fish_mamba_has_command remove' -a '(__fish_mamba_packages)'
complete -x -c micromamba -n '__fish_mamba_has_command uninstall' -a '(__fish_mamba_packages)'
complete -x -c micromamba -n '__fish_mamba_has_command upgrade' -a '(__fish_mamba_packages)'
complete -x -c micromamba -n '__fish_mamba_has_command update' -a '(__fish_mamba_packages)'
complete -x -c mamba -n '__fish_mamba_has_command remove' -a '(__fish_mamba_packages)'
complete -x -c mamba -n '__fish_mamba_has_command uninstall' -a '(__fish_mamba_packages)'
complete -x -c mamba -n '__fish_mamba_has_command upgrade' -a '(__fish_mamba_packages)'
complete -x -c mamba -n '__fish_mamba_has_command update' -a '(__fish_mamba_packages)'

# Environment name
complete -x -c micromamba -n '__fish_mamba_needs_env' -a '(__fish_mamba_envs)'
complete -x -c mamba -n '__fish_mamba_needs_env' -a '(__fish_mamba_envs)'
